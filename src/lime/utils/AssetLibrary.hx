// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

import haxe.io.Bytes;
import lime.app.Event;
import lime.app.Future;
import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;

class AssetLibrary {
	public var onChange = new Event<Void->Void>();

	private var paths:Map<String, String> = new Map<String, String>();
	private var types:Map<String, AssetType> = new Map<String, AssetType>();

	public function new() {}

	public function exists(id:String, type:String):Bool {
		if (paths.exists(id)) {
			return type == null || types.get(id) == type;
		}
		return sys.FileSystem.exists(id);
	}

	public static function fromBytes(bytes:Bytes, rootPath:String = null):AssetLibrary {
		return fromManifest(AssetManifest.fromBytes(bytes, rootPath));
	}

	public static function fromFile(path:String, rootPath:String = null):AssetLibrary {
		return fromManifest(AssetManifest.fromFile(path, rootPath));
	}

	public static function fromManifest(manifest:AssetManifest):AssetLibrary {
		if (manifest == null) return null;
		var library = new AssetLibrary();
		if (manifest.assets != null) {
			for (asset in manifest.assets) {
				var id:String = Reflect.field(asset, "id");
				var path:String = Reflect.field(asset, "path");
				var type:String = Reflect.field(asset, "type");
				if (id != null && path != null) {
					var full = manifest.rootPath != null ? haxe.io.Path.join([manifest.rootPath, path]) : path;
					library.paths.set(id, full);
					if (type != null) library.types.set(id, cast type);
				}
			}
		}
		return library;
	}

	public function getAsset(id:String, type:String):Dynamic {
		return switch ((type : AssetType)) {
			case BINARY: getBytes(id);
			case FONT: getFont(id);
			case IMAGE: getImage(id);
			case MUSIC, SOUND: getAudioBuffer(id);
			case TEXT: getText(id);
			default: null;
		};
	}

	public function getAudioBuffer(id:String):AudioBuffer {
		return AudioBuffer.fromFile(getPath(id));
	}

	public function getBytes(id:String):Bytes {
		var p = getPath(id);
		return (p != null && sys.FileSystem.exists(p)) ? sys.io.File.getBytes(p) : null;
	}

	public function getFont(id:String):Font {
		return Font.fromFile(getPath(id));
	}

	public function getImage(id:String):Image {
		return Image.fromFile(getPath(id));
	}

	public function getPath(id:String):String {
		return paths.exists(id) ? paths.get(id) : id;
	}

	public function getText(id:String):String {
		var p = getPath(id);
		return (p != null && sys.FileSystem.exists(p)) ? sys.io.File.getContent(p) : null;
	}

	public function isLocal(id:String, type:String):Bool {
		return true;
	}

	public function list(type:String):Array<String> {
		var items:Array<String> = [];
		for (id => t in types) {
			if (type == null || t == type) items.push(id);
		}
		return items;
	}

	public function load():Future<AssetLibrary> {
		return Future.withValue(this);
	}

	public function loadAsset(id:String, type:String):Future<Dynamic> {
		return switch ((type : AssetType)) {
			case BINARY: loadBytes(id);
			case FONT: loadFont(id);
			case IMAGE: loadImage(id);
			case MUSIC, SOUND: loadAudioBuffer(id);
			case TEXT: loadText(id);
			default: Future.withValue(null);
		};
	}

	public function loadAudioBuffer(id:String):Future<AudioBuffer> {
		return AudioBuffer.loadFromFile(getPath(id));
	}

	public function loadBytes(id:String):Future<Bytes> {
		return new Future<Bytes>(() -> getBytes(id), true);
	}

	public static function loadFromBytes(bytes:Bytes, rootPath:String = null):Future<AssetLibrary> {
		return Future.withValue(fromBytes(bytes, rootPath));
	}

	public static function loadFromFile(path:String, rootPath:String = null):Future<AssetLibrary> {
		return new Future<AssetLibrary>(() -> fromFile(path, rootPath), true);
	}

	public static function loadFromManifest(manifest:AssetManifest):Future<AssetLibrary> {
		return Future.withValue(fromManifest(manifest));
	}

	public function loadFont(id:String):Future<Font> {
		return Font.loadFromFile(getPath(id));
	}

	public function loadImage(id:String):Future<Image> {
		return Image.loadFromFile(getPath(id));
	}

	public function loadText(id:String):Future<String> {
		return new Future<String>(() -> getText(id), true);
	}

	public function unload():Void {}
}
