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

	public function new(name:String = null) {
		this.name = name != null ? name : "Arimo";
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
		var s:TextStyle = style != null ? style : {};
		if (s.family == null && name != null && name != "Sans") s.family = name;
		if (s.size == null) s.size = size;
		getAtlas(batcher != null ? batcher.context3D : null).drawText(batcher, text, x, y, size, color, alpha, s);
	}

	public static function fromBytes(bytes:Bytes):Font {
		if (bytes == null) return null;
		Fonts.register(bytes);
		var font = new Font();
		font.__fontBytes = bytes;
		font.refreshMetrics();
		return font;
	}

	public static function fromFile(path:String):Font {
		if (path == null) return null;
		var fontName = haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(path));
		var bytes:Null<Bytes> = null;
		if (sys.FileSystem.exists(path)) {
			bytes = sys.io.File.getBytes(path);
			Fonts.register(bytes);
		}
		var font = new Font(fontName);
		font.__fontPath = path;
		font.__fontBytes = bytes;
		return font;
	}

	public static function loadFromBytes(bytes:Bytes):Future<Font> {
		return new Future<Font>(() -> fromBytes(bytes), true);
	}

	public static function loadFromFile(path:String):Future<Font> {
		return new Future<Font>(() -> fromFile(path), true);
	}
}
