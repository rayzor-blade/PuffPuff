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

	static var __defaultAtlas:Null<FontAtlas>;
	static var __gammaLut:Null<Bytes>;

	final info:Bytes = Bytes.alloc(28);
	var rawPixels:Bytes = Bytes.alloc(0);
	var rgbaPixels:Bytes = Bytes.alloc(0);
	var seen:Int = 0;
	var colorSeen:Int = 0;

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

	/**
	 * Shapes `text` and rasterizes its glyphs into the native atlas, returning glyph positions,
	 * atlas pixel rects, and line metrics.
	 */
	public function prepare(text:String, ?style:TextStyle):PreparedRun {
		Fonts.ensureBundled();
		var s:TextStyle = style != null ? style : {};
		var size:Float = s.size != null ? s.size : 16.0;
		var weight:Int = s.weight != null ? s.weight : 400;
		var italic = s.italic == true;
		var generic:Int = s.generic != null ? s.generic : 0;
		var spacing:Float = s.letterSpacing != null ? s.letterSpacing : 0.0;
		var leading:Float = s.lineHeight != null ? s.lineHeight : 0.0;

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
		var runInfo = new hl.Bytes(16);
		var fontBytes = s.family == null ? null : TextUtf8.encode(s.family);
		var textBytes = TextUtf8.encode(text);
		var capacity = (text.length + 8) * 9;
		var out = new hl.Bytes(capacity * 4);
		var set = new hl.Bytes(24);
		set.setF32(0, generic * 1.0);
		set.setF32(4, weight * 1.0);
		set.setF32(8, italic ? 1.0 : 0.0);
		set.setF32(12, size);
		set.setF32(16, spacing);
		set.setF32(20, leading);

		var n = TextNative.blinc_text_prepare(textBytes, fontBytes, set, out, capacity, runInfo);
		if (n > capacity) {
			capacity = n;
			out = new hl.Bytes(capacity * 4);
			n = TextNative.blinc_text_prepare(textBytes, fontBytes, set, out, capacity, runInfo);
		}

		var count = Std.int(n / 9);
		var glyphs:Array<PreparedGlyph> = [];
		for (i in 0...count) {
			var base = i * 36;
			glyphs.push({
				x: out.getF32(base),
				y: out.getF32(base + 4),
				width: out.getF32(base + 8),
				height: out.getF32(base + 12),
				u0: out.getF32(base + 16),
				v0: out.getF32(base + 20),
				u1: out.getF32(base + 24),
				v1: out.getF32(base + 28),
				isColor: out.getF32(base + 32) > 0.5
			});
		}

		return {
			glyphs: glyphs,
			width: runInfo.getF32(0),
			ascent: runInfo.getF32(4),
			descent: runInfo.getF32(8),
			lineHeight: runInfo.getF32(12)
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
		var s:TextStyle = style != null ? {
			size: style.size != null ? style.size : size,
			family: style.family,
			generic: style.generic,
			weight: style.weight,
			italic: style.italic,
			letterSpacing: style.letterSpacing,
			lineHeight: style.lineHeight
		} : {size: size};
		var run = prepare(text, s);
		return {
			width: run.width,
			ascent: run.ascent,
			descent: run.descent,
			lineHeight: run.lineHeight
		};
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
		var s:TextStyle = style != null ? {
			size: style.size != null ? style.size : size,
			family: style.family,
			generic: style.generic,
			weight: style.weight,
			italic: style.italic,
			letterSpacing: style.letterSpacing,
			lineHeight: style.lineHeight,
			pixel: style.pixel
		} : {size: size};

		var run = prepare(text, s);
		sync(batcher.context3D);
		if (texture == null) return;

		if (batcher.texture == null) {
			batcher.begin(texture);
		}

		var invW = 1.0 / texture.width;
		var invH = 1.0 / texture.height;
		var colorInvW = colorTexture != null ? 1.0 / colorTexture.width : invW;
		var colorInvH = colorTexture != null ? 1.0 / colorTexture.height : invH;
		var pixelSnap = s.pixel == true;
		var effectiveAlpha = pixelSnap ? -Math.abs(alpha) : alpha;

		for (g in run.glyphs) {
			if (g.width <= 0 || g.height <= 0) continue;
			var iw = g.isColor ? colorInvW : invW;
			var ih = g.isColor ? colorInvH : invH;
			// Whole-pixel placement: subpixel X phase is baked into the glyph bitmap by blinc_abi,
			// and rounding Y snaps the line baseline so atlas texel rows map 1:1 to screen pixels.
			var gx = Math.round(x + g.x);
			var gy = Math.round(y + g.y);
			batcher.addQuad(
				g.width, 0.0, 0.0, g.height,
				gx, gy,
				g.u0 * iw, g.v0 * ih, (g.u1 - g.u0) * iw, (g.v1 - g.v0) * ih,
				effectiveAlpha, g.isColor ? 0xFFFFFF : color
			);
		}
	}
}
