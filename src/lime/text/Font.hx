// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.text;

import haxe.io.Bytes;
import lime.app.Future;
import puffpuff.gpu.QuadBatcher;
import puffpuff.gpu.WgpuContext3D;
import puffpuff.text.FontAtlas;
import puffpuff.text.Fonts;
import puffpuff.text.GlyphOutlines;
import puffpuff.text.GlyphOutlines.TextOutline;
import puffpuff.text.GlyphOutlines.TextStyle;

class Font {
	public var ascender:Int;
	public var descender:Int;
	public var height:Int;
	public var name(default, null):String;
	public var numGlyphs:Int;
	public var src:Dynamic;
	public var underlinePosition:Int;
	public var underlineThickness:Int;
	public var unitsPerEM:Int;

	/**
	 * Enables crisp 1-bit thresholded pixel rendering and integer coordinate snapping
	 * for pixel-genre TTF fonts.
	 */
	public var pixelMode:Bool = false;

	@:noCompletion public var __fontPath:Null<String>;
	@:noCompletion public var __fontBytes:Null<Bytes>;
	@:noCompletion public var __atlas:Null<FontAtlas>;

	public function getAtlas(context3D:WgpuContext3D = null):FontAtlas {
		if (__atlas == null) {
			__atlas = FontAtlas.getDefault(context3D);
		} else if (context3D != null) {
			__atlas.upload(context3D);
		}
		return __atlas;
	}

	public function new(name:String = null, pixelMode:Bool = false) {
		this.name = name != null ? name : "Arimo";
		this.pixelMode = pixelMode;
		this.unitsPerEM = 1000;
		this.numGlyphs = 65535;
		this.underlinePosition = -100;
		this.underlineThickness = 50;
		refreshMetrics();
	}

	function refreshMetrics():Void {
		var outline = GlyphOutlines.of("M", {
			family: name == "Sans" ? null : name,
			size: unitsPerEM * 1.0
		});
		if (outline != null && outline.ascent > 0) {
			this.ascender = Std.int(Math.round(outline.ascent));
			this.descender = -Std.int(Math.round(outline.descent));
			this.height = Std.int(Math.round(outline.lineHeight));
		} else {
			this.ascender = 800;
			this.descender = -200;
			this.height = 1000;
		}
	}

	public function getGlyph(character:String):Int {
		return (character != null && character.length > 0) ? character.charCodeAt(0) : 0;
	}

	public function getGlyphs(characters:String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}\\|;':\",./<>?`~"):Array<Int> {
		var result:Array<Int> = [];
		if (characters == null) return result;
		for (i in 0...characters.length) {
			result.push(characters.charCodeAt(i));
		}
		return result;
	}

	public function measureText(text:String, size:Float = 16.0, ?style:TextStyle):{width:Float, ascent:Float, descent:Float, lineHeight:Float} {
		var s:TextStyle = style != null ? style : {};
		if (s.family == null && name != null && name != "Sans") s.family = name;
		if (s.size == null) s.size = size;
		return getAtlas().measureText(text, size, s);
	}

	public function getOutline(text:String, size:Float = 16.0, ?style:TextStyle):Null<TextOutline> {
		var s:TextStyle = style != null ? style : {};
		if (s.family == null && name != null && name != "Sans") s.family = name;
		if (s.size == null) s.size = size;
		return GlyphOutlines.of(text, s);
	}

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
		var s:TextStyle = style != null ? {
			size: style.size != null ? style.size : size,
			family: style.family != null ? style.family : (name != null && name != "Sans" ? name : null),
			generic: style.generic,
			weight: style.weight,
			italic: style.italic,
			letterSpacing: style.letterSpacing,
			lineHeight: style.lineHeight,
			pixel: style.pixel != null ? style.pixel : pixelMode
		} : {
			size: size,
			family: name != null && name != "Sans" ? name : null,
			pixel: pixelMode
		};
		getAtlas(batcher != null ? batcher.context3D : null).drawText(batcher, text, x, y, size, color, alpha, s);
	}

	public static function fromBytes(bytes:Bytes, pixelMode:Bool = false):Font {
		if (bytes == null) return null;
		Fonts.register(bytes);
		var font = new Font("Arimo", pixelMode);
		font.__fromBytes(bytes);
		return font;
	}

	public static function fromFile(path:String, pixelMode:Bool = false):Font {
		if (path == null) return null;
		var resolved = resolvePath(path);
		if (resolved != null) {
			var bytes = sys.io.File.getBytes(resolved);
			var font = fromBytes(bytes, pixelMode);
			font.__fontPath = resolved;
			return font;
		}
		var fallbackName = haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(path));
		var font = new Font(fallbackName, pixelMode);
		font.__fontPath = path;
		return font;
	}

	static function resolvePath(path:String):Null<String> {
		if (sys.FileSystem.exists(path)) return path;
		for (prefix in ["..", "../..", "../../.."]) {
			var candidate = '$prefix/$path';
			if (sys.FileSystem.exists(candidate)) return candidate;
		}
		return null;
	}

	public static function loadFromBytes(bytes:Bytes):Future<Font> {
		return new Future<Font>(() -> fromBytes(bytes), true);
	}

	public static function loadFromFile(path:String):Future<Font> {
		return new Future<Font>(() -> fromFile(path), true);
	}

	@:noCompletion public function __fromBytes(bytes:Bytes):Void {
		__fontBytes = bytes;
		if (bytes == null || bytes.length < 12) return;

		var sfnt = readU32BE(bytes, 0);
		// TrueType (0x00010000, 'true') or OpenType ('OTTO')
		if (sfnt != 0x00010000 && sfnt != 0x74727565 && sfnt != 0x4F54544F) {
			refreshMetrics();
			return;
		}

		var numTables = readU16BE(bytes, 4);
		if (12 + numTables * 16 > bytes.length) return;

		var headOff = -1;
		var hheaOff = -1;
		var maxpOff = -1;
		var postOff = -1;
		var nameOff = -1;
		var nameLen = 0;

		for (i in 0...numTables) {
			var rec = 12 + i * 16;
			var tag = bytes.getString(rec, 4);
			var off = readU32BE(bytes, rec + 8);
			var len = readU32BE(bytes, rec + 12);
			if (off < 0 || off + len > bytes.length) continue;
			switch (tag) {
				case "head": headOff = off;
				case "hhea": hheaOff = off;
				case "maxp": maxpOff = off;
				case "post": postOff = off;
				case "name":
					nameOff = off;
					nameLen = len;
				default:
			}
		}

		if (headOff >= 0 && headOff + 20 <= bytes.length) {
			var upem = readU16BE(bytes, headOff + 18);
			if (upem > 0) unitsPerEM = upem;
		}
		if (hheaOff >= 0 && hheaOff + 10 <= bytes.length) {
			ascender = readI16BE(bytes, hheaOff + 4);
			descender = readI16BE(bytes, hheaOff + 6);
			var lineGap = readI16BE(bytes, hheaOff + 8);
			height = ascender - descender + lineGap;
		}
		if (maxpOff >= 0 && maxpOff + 6 <= bytes.length) {
			numGlyphs = readU16BE(bytes, maxpOff + 4);
		}
		if (postOff >= 0 && postOff + 12 <= bytes.length) {
			underlinePosition = readI16BE(bytes, postOff + 8);
			underlineThickness = readI16BE(bytes, postOff + 10);
		}
		if (nameOff >= 0) {
			var parsedFamily = extractTtfFamilyName(bytes, nameOff, nameLen);
			if (parsedFamily != null && parsedFamily.length > 0) {
				this.name = parsedFamily;
			}
		}
	}

	static function extractTtfFamilyName(bytes:Bytes, tableOff:Int, tableLen:Int):Null<String> {
		if (tableLen < 6) return null;
		var count = readU16BE(bytes, tableOff + 2);
		var stringOffset = readU16BE(bytes, tableOff + 4);
		var storageBase = tableOff + stringOffset;

		var bestName:Null<String> = null;
		var bestPriority = -1;

		for (i in 0...count) {
			var rec = tableOff + 6 + i * 12;
			if (rec + 12 > tableOff + tableLen) break;
			var platformID = readU16BE(bytes, rec);
			var encodingID = readU16BE(bytes, rec + 2);
			var languageID = readU16BE(bytes, rec + 4);
			var nameID = readU16BE(bytes, rec + 6);
			var strLen = readU16BE(bytes, rec + 8);
			var strOff = readU16BE(bytes, rec + 10);

			// nameID 16 = Typographic Family, nameID 1 = Font Family
			if (nameID != 1 && nameID != 16) continue;
			var absOff = storageBase + strOff;
			if (absOff < 0 || absOff + strLen > bytes.length || strLen <= 0) continue;

			var priority = (nameID == 16 ? 10 : 5);
			var decoded:Null<String> = null;

			if (platformID == 0 || (platformID == 3 && (encodingID == 1 || encodingID == 10))) {
				// UTF-16BE
				if (platformID == 3 && languageID == 0x0409) priority += 2;
				var buf = new StringBuf();
				var nChars = strLen >> 1;
				for (c in 0...nChars) {
					var code = readU16BE(bytes, absOff + c * 2);
					if (code > 0) buf.addChar(code);
				}
				decoded = buf.toString();
			} else if (platformID == 1 && encodingID == 0) {
				// MacRoman / ASCII
				var buf = new StringBuf();
				for (c in 0...strLen) {
					var code = bytes.get(absOff + c);
					if (code > 0) buf.addChar(code);
				}
				decoded = buf.toString();
			}

			if (decoded != null && decoded.length > 0 && priority > bestPriority) {
				bestName = decoded;
				bestPriority = priority;
			}
		}

		return bestName;
	}

	static inline function readU16BE(b:Bytes, pos:Int):Int {
		return (b.get(pos) << 8) | b.get(pos + 1);
	}

	static inline function readI16BE(b:Bytes, pos:Int):Int {
		var v = (b.get(pos) << 8) | b.get(pos + 1);
		return (v & 0x8000) != 0 ? v - 0x10000 : v;
	}

	static inline function readU32BE(b:Bytes, pos:Int):Int {
		return (b.get(pos) << 24) | (b.get(pos + 1) << 16) | (b.get(pos + 2) << 8) | b.get(pos + 3);
	}
}
