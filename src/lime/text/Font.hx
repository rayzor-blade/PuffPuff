package lime.text;

import haxe.io.Bytes;
import lime.app.Future;

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

	public function new(name:String = null) {
		this.name = name != null ? name : "Sans";
		this.ascender = 800;
		this.descender = -200;
		this.height = 1000;
		this.unitsPerEM = 1000;
		this.numGlyphs = 256;
	}

	public static function fromBytes(bytes:Bytes):Font {
		if (bytes == null) return null;
		var font = new Font();
		font.__fontBytes = bytes;
		return font;
	}

	public static function fromFile(path:String):Font {
		if (path == null) return null;
		var font = new Font(haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(path)));
		font.__fontPath = path;
		if (sys.FileSystem.exists(path)) {
			font.__fontBytes = sys.io.File.getBytes(path);
		}
		return font;
	}

	public static function loadFromBytes(bytes:Bytes):Future<Font> {
		return new Future<Font>(() -> fromBytes(bytes), true);
	}

	public static function loadFromFile(path:String):Future<Font> {
		return new Future<Font>(() -> fromFile(path), true);
	}
}
