package puffpuff.text;

import haxe.io.Bytes;
import puffpuff.gpu.QuadBatcher;
import puffpuff.gpu.WgpuContext3D;
import puffpuff.gpu.WgpuContext3D.WgpuTexture;
import puffpuff.text.GlyphOutlines.TextStyle;
import puffpuff.text.TextNative.TextUtf8;

typedef PreparedGlyph = {
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
	var u0:Float;
	var v0:Float;
	var u1:Float;
	var v1:Float;
	var isColor:Bool;
}

typedef PreparedRun = {
	var glyphs:Array<PreparedGlyph>;
	var width:Float;
	var ascent:Float;
	var descent:Float;
	var lineHeight:Float;
}

/**
 * GPU glyph atlas and text shaper powered by `blinc_abi`.
 * Shapes Unicode text with kerning, fallback fonts, and variable weights via `blinc_text_prepare`,
 * and incrementally syncs dirty sub-rectangles from the native coverage and color atlases.
 */
class FontAtlas {
	public var texture(default, null):Null<WgpuTexture>;
	public var colorTexture(default, null):Null<WgpuTexture>;
	public var revision(default, null):Int = 0;
	public var colorRevision(default, null):Int = 0;

	/** How many times the native atlases were cleared. Glyph rectangles from before a clear are stale. **/
	public var generation(get, never):Int;

	static var __defaultAtlas:Null<FontAtlas>;
	static var __gammaLut:Null<Bytes>;

	final info:Bytes = Bytes.alloc(28);

	// Buffers `shape` fills, kept between calls.
	#if hl
	var shapeOut:hl.Bytes = new hl.Bytes(9 * 4 * 256);
	var shapeCapacity = 256 * 9;
	final shapeInfo:hl.Bytes = new hl.Bytes(16);
	final shapeStyle:hl.Bytes = new hl.Bytes(24);
	var familyName:Null<String>;
	var familyBytes:Null<hl.Bytes>;
	#end

	var rawPixels:Bytes = Bytes.alloc(0);
	var rgbaPixels:Bytes = Bytes.alloc(0);
	var seen:Int = 0;
	var colorSeen:Int = 0;

	function get_generation():Int {
		#if hl
		return TextNative.blinc_text_generation();
		#else
		return 0;
		#end
	}

	/**
	 * Whether lines are composed from words shaped once (the default) or shaped whole each time. Both place glyphs within a
	 * third of a pixel. Whole lines exist so tests can compare. Returns the previous setting.
	 */
	public static function wordCache(enabled:Bool):Bool {
		#if hl
		return TextNative.blinc_text_word_cache(enabled ? 1 : 0) != 0;
		#else
		return true;
		#end
	}

	public static function getDefault(context3D:WgpuContext3D = null):FontAtlas {
		if (__defaultAtlas == null) {
			__defaultAtlas = new FontAtlas();
		}
		if (context3D != null) {
			__defaultAtlas.upload(context3D);
		}
		return __defaultAtlas;
	}

	static function getGammaLut():Bytes {
		if (__gammaLut == null) {
			__gammaLut = Bytes.alloc(256);
			for (i in 0...256) {
				var lifted = Std.int(Math.pow(i / 255.0, 0.7) * 255.0 + 0.5);
				__gammaLut.set(i, lifted > 255 ? 255 : lifted);
			}
		}
		return __gammaLut;
	}

	public function new() {
		Fonts.ensureBundled();
	}

	public function upload(context3D:WgpuContext3D):WgpuTexture {
		if (context3D == null) return texture;
		if (texture == null) {
			texture = context3D.createTexture(1, 1);
		}
		if (colorTexture == null) {
			colorTexture = context3D.createTexture(1, 1);
		}
		sync(context3D);
		return texture;
	}

	/**
	 * Synchronizes both the coverage glyph atlas and the color-emoji glyph atlas with the GPU.
	 */
	public function sync(context3D:WgpuContext3D):Void {
		if (context3D == null) return;
		if (texture == null) texture = context3D.createTexture(1, 1);
		if (colorTexture == null) colorTexture = context3D.createTexture(1, 1);
		syncTarget(texture, false);
		syncTarget(colorTexture, true);
	}

	function syncTarget(target:WgpuTexture, color:Bool):Void {
		#if hl
		var which = color ? 1 : 0;
		var currentSeen = color ? colorSeen : seen;
		if (!take(which, currentSeen)) return;

		var width = info.getInt32(0);
		var height = info.getInt32(4);
		if (width <= 0 || height <= 0) return;

		if (target.width != width || target.height != height) {
			target.resize(width, height);
			if (info.getInt32(20) != width || info.getInt32(24) != height) {
				if (!take(which, 0)) return;
			}
			if (color) colorRevision++; else revision++;
		}

		var nextSeen = info.getInt32(8);
		if (color) colorSeen = nextSeen; else seen = nextSeen;

		var x = info.getInt32(12);
		var y = info.getInt32(16);
		var w = info.getInt32(20);
		var h = info.getInt32(24);
		if (w <= 0 || h <= 0) return;

		if (color) {
			target.uploadRegion(x, y, w, h, rawPixels, w * 4);
		} else {
			var count = w * h;
			var needed = count * 4;
			if (rgbaPixels.length < needed) {
				rgbaPixels = Bytes.alloc(needed);
			}
			var lut = getGammaLut();
			for (i in 0...count) {
				var cov = rawPixels.get(i);
				var off = i << 2;
				rgbaPixels.set(off, 255);
				rgbaPixels.set(off + 1, 255);
				rgbaPixels.set(off + 2, 255);
				rgbaPixels.set(off + 3, lut.get(cov));
			}
			target.uploadRegion(x, y, w, h, rgbaPixels, w * 4);
		}
		#end
	}

	function take(which:Int, since:Int):Bool {
		#if hl
		var size = TextNative.blinc_text_atlas_take(which, since, rawPixels.getData(), rawPixels.length, info.getData());
		if (size == 0) return false;
		if (size > rawPixels.length) {
			rawPixels = Bytes.alloc(size + (size >> 1));
			size = TextNative.blinc_text_atlas_take(which, since, rawPixels.getData(), rawPixels.length, info.getData());
		}
		return size > 0;
		#else
		return false;
		#end
	}

	#if hl
	/**
	 * Shapes `text` into `shapeOut` and the line metrics into `shapeInfo`. Returns how many f32s were written
	 * (`glyphs * 9`).
	 */
	function shape(text:String, size:Float, style:Null<TextStyle>):Int {
		Fonts.ensureBundled();
		var family:Null<String> = null;
		var weight = 400;
		var italic = false;
		var generic = 0;
		var spacing = 0.0;
		var leading = 0.0;
		if (style != null) {
			if (style.size != null) size = style.size;
			family = style.family;
			if (style.weight != null) weight = style.weight;
			italic = style.italic == true;
			if (style.generic != null) generic = style.generic;
			if (style.letterSpacing != null) spacing = style.letterSpacing;
			if (style.lineHeight != null) leading = style.lineHeight;
		}
		if (family != familyName) {
			familyName = family;
			familyBytes = family == null ? null : TextUtf8.encode(family);
		}
		shapeStyle.setF32(0, generic * 1.0);
		shapeStyle.setF32(4, weight * 1.0);
		shapeStyle.setF32(8, italic ? 1.0 : 0.0);
		shapeStyle.setF32(12, size);
		shapeStyle.setF32(16, spacing);
		shapeStyle.setF32(20, leading);

		var textBytes = TextUtf8.encode(text);
		var n = TextNative.blinc_text_prepare(textBytes, familyBytes, shapeStyle, shapeOut, shapeCapacity, shapeInfo);
		if (n > shapeCapacity) {
			shapeCapacity = n + (n >> 1);
			shapeOut = new hl.Bytes(shapeCapacity * 4);
			n = TextNative.blinc_text_prepare(textBytes, familyBytes, shapeStyle, shapeOut, shapeCapacity, shapeInfo);
		}
		return n;
	}
	#end

	/**
	 * Shapes `text` and rasterizes its glyphs into the native atlas, returning glyph positions,
	 * atlas pixel rects, and line metrics.
	 */
	public function prepare(text:String, ?style:TextStyle):PreparedRun {
		var size:Float = style != null && style.size != null ? style.size : 16.0;
		if (text == null || text.length == 0) {
			return {
				glyphs: [],
				width: 0.0,
				ascent: size * 0.8,
				descent: size * 0.2,
				lineHeight: size * 1.2
			};
		}

		#if hl
		var n = shape(text, size, style);
		var count = Std.int(n / 9);
		var glyphs:Array<PreparedGlyph> = [];
		for (i in 0...count) {
			var base = i * 36;
			glyphs.push({
				x: shapeOut.getF32(base),
				y: shapeOut.getF32(base + 4),
				width: shapeOut.getF32(base + 8),
				height: shapeOut.getF32(base + 12),
				u0: shapeOut.getF32(base + 16),
				v0: shapeOut.getF32(base + 20),
				u1: shapeOut.getF32(base + 24),
				v1: shapeOut.getF32(base + 28),
				isColor: shapeOut.getF32(base + 32) > 0.5
			});
		}

		return {
			glyphs: glyphs,
			width: shapeInfo.getF32(0),
			ascent: shapeInfo.getF32(4),
			descent: shapeInfo.getF32(8),
			lineHeight: shapeInfo.getF32(12)
		};
		#else
		return {
			glyphs: [],
			width: 0.0,
			ascent: size * 0.8,
			descent: size * 0.2,
			lineHeight: size * 1.2
		};
		#end
	}

	public function measureText(text:String, size:Float = 16.0, ?style:TextStyle):{width:Float, ascent:Float, descent:Float, lineHeight:Float} {
		#if hl
		if (text != null && text.length > 0) {
			shape(text, size, style);
			return {
				width: shapeInfo.getF32(0),
				ascent: shapeInfo.getF32(4),
				descent: shapeInfo.getF32(8),
				lineHeight: shapeInfo.getF32(12)
			};
		}
		#end
		return {width: 0.0, ascent: size * 0.8, descent: size * 0.2, lineHeight: size * 1.2};
	}

	/**
	 * Shapes `text`, syncs the GPU glyph atlas, and queues instanced glyph quads into `batcher`.
	 */
	public function drawText(
		batcher:QuadBatcher,
		text:String,
		x:Float,
		y:Float,
		size:Float = 16.0,
		color:Int = 0xFFFFFF,
		alpha:Float = 1.0,
		?style:TextStyle
	):Void {
		if (batcher == null || text == null || text.length == 0) return;
		#if hl
		var n = shape(text, size, style);
		sync(batcher.context3D);
		if (texture == null) return;

		if (batcher.texture == null) {
			batcher.begin(texture);
		}

		var invW = 1.0 / texture.width;
		var invH = 1.0 / texture.height;
		var colorInvW = colorTexture != null ? 1.0 / colorTexture.width : invW;
		var colorInvH = colorTexture != null ? 1.0 / colorTexture.height : invH;
		var pixelSnap = style != null && style.pixel == true;
		var effectiveAlpha = pixelSnap ? -Math.abs(alpha) : alpha;

		for (i in 0...Std.int(n / 9)) {
			var base = i * 36;
			var width = shapeOut.getF32(base + 8);
			var height = shapeOut.getF32(base + 12);
			if (width <= 0 || height <= 0) continue;
			var isColor = shapeOut.getF32(base + 32) > 0.5;
			var iw = isColor ? colorInvW : invW;
			var ih = isColor ? colorInvH : invH;
			var u0 = shapeOut.getF32(base + 16);
			var v0 = shapeOut.getF32(base + 20);
			// Whole-pixel placement: subpixel X phase is baked into the glyph bitmap by blinc_abi,
			// and rounding Y snaps the line baseline so atlas texel rows map 1:1 to screen pixels.
			var gx = Math.round(x + shapeOut.getF32(base));
			var gy = Math.round(y + shapeOut.getF32(base + 4));
			batcher.addQuad(
				width, 0.0, 0.0, height,
				gx, gy,
				u0 * iw, v0 * ih, (shapeOut.getF32(base + 24) - u0) * iw, (shapeOut.getF32(base + 28) - v0) * ih,
				effectiveAlpha, isColor ? 0xFFFFFF : color
			);
		}
		#end
	}
}
