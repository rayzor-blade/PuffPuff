// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

import haxe.Json;
import haxe.io.Bytes;
import lime.app.Future;

class AssetManifest {
	public var assets:Array<Dynamic>;
	public var libraryArgs:Array<String>;
	public var libraryType:String;
	public var name:String;
	public var rootPath:String;
	public var version:Int;

	public function new() {
		assets = [];
		libraryArgs = [];
		version = 2;
	}

	public static function fromBytes(bytes:Bytes, rootPath:String = null):AssetManifest {
		if (bytes == null) return null;
		return parse(bytes.toString(), rootPath);
	}

	public static function fromFile(path:String, rootPath:String = null):AssetManifest {
		if (path == null || !sys.FileSystem.exists(path)) return null;
		return parse(sys.io.File.getContent(path), rootPath);
	}

	public static function loadFromBytes(bytes:Bytes, rootPath:String = null):Future<AssetManifest> {
		return Future.withValue(fromBytes(bytes, rootPath));
	}

	public static function loadFromFile(path:String, rootPath:String = null):Future<AssetManifest> {
		return new Future<AssetManifest>(() -> fromFile(path, rootPath), true);
	}

	public static function parse(data:String, rootPath:String = null):AssetManifest {
		if (data == null || data == "") return null;
		var manifest = new AssetManifest();
		manifest.rootPath = rootPath;
		try {
			var parsed:Dynamic = Json.parse(data);
			if (Reflect.hasField(parsed, "assets")) manifest.assets = parsed.assets;
			if (Reflect.hasField(parsed, "libraryArgs")) manifest.libraryArgs = parsed.libraryArgs;
			if (Reflect.hasField(parsed, "libraryType")) manifest.libraryType = parsed.libraryType;
			if (Reflect.hasField(parsed, "name")) manifest.name = parsed.name;
			if (Reflect.hasField(parsed, "version")) manifest.version = parsed.version;
		} catch (_:Dynamic) {}
		return manifest;
	}

	public function serialize():String {
		return Json.stringify({
			version: version,
			libraryArgs: libraryArgs,
			libraryType: libraryType,
			name: name,
			assets: assets
		});
	}
}
