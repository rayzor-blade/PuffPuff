// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

import haxe.io.Bytes;
import lime.app.Event;
import lime.app.Future;
import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;

/**
 * Lime Assets facade backed by `ash-future`, `hlavi`, and `puffpuff.snapshot.Png`.
 */
class Assets {
	public static var cache:AssetCache = new AssetCache();
	public static var onChange = new Event<Void->Void>();

	private static var __assetPaths:Map<String, String> = new Map<String, String>();
	private static var __assetTypes:Map<String, AssetType> = new Map<String, AssetType>();
	private static var __libraries:Map<String, AssetLibrary> = new Map<String, AssetLibrary>();

	public static function registerPath(id:String, path:String, type:AssetType = null):Void {
		__assetPaths.set(id, path);
		if (type != null) __assetTypes.set(id, type);
	}

	public static function registerLibrary(name:String, library:AssetLibrary):Void {
		if (name == null || name == "") name = "default";
		__libraries.set(name, library);
	}

	public static function getLibrary(name:String):AssetLibrary {
		if (name == null || name == "") name = "default";
		return __libraries.get(name);
	}

	public static function loadLibrary(name:String):Future<AssetLibrary> {
		var lib = getLibrary(name);
		if (lib != null) return lib.load();
		return Future.withValue(new AssetLibrary());
	}

	public static function unloadLibrary(name:String):Void {
		if (name == null || name == "") name = "default";
		var lib = __libraries.get(name);
		if (lib != null) {
			lib.unload();
			__libraries.remove(name);
		}
	}

	public static function getPath(id:String):String {
		return resolvePath(id);
	}

	public static function isLocal(id:String, type:AssetType = null, useCache:Bool = true):Bool {
		return true;
	}

	public static function list(type:AssetType = null):Array<String> {
		var items:Array<String> = [];
		for (id in __assetPaths.keys()) {
			if (type == null || __assetTypes.get(id) == type) {
				items.push(id);
			}
		}
		for (lib in __libraries) {
			for (id in lib.list(type)) {
				if (items.indexOf(id) < 0) items.push(id);
			}
		}
		return items;
	}

	private static function resolvePath(id:String):String {
		if (__assetPaths.exists(id)) return __assetPaths.get(id);
		var colon = id != null ? id.indexOf(":") : -1;
		if (colon > 0) {
			var libName = id.substr(0, colon);
			var sym = id.substr(colon + 1);
			var lib = __libraries.get(libName);
			if (lib != null) return lib.getPath(sym);
		}
		var defaultLib = __libraries.get("default");
		if (defaultLib != null && defaultLib.exists(id, null)) {
			return defaultLib.getPath(id);
		}
		return id;
	}

	public static function exists(id:String, type:AssetType = null):Bool {
		var path = resolvePath(id);
		return path != null && sys.FileSystem.exists(path);
	}

	public static function getBytes(id:String):Bytes {
		var path = resolvePath(id);
		if (path == null || !sys.FileSystem.exists(path)) return null;
		return sys.io.File.getBytes(path);
	}

	public static function getText(id:String):String {
		var path = resolvePath(id);
		if (path == null || !sys.FileSystem.exists(path)) return null;
		return sys.io.File.getContent(path);
	}

	public static function getImage(id:String, useCache:Bool = true):Image {
		if (useCache && cache.enabled && cache.image.exists(id)) {
			return cache.image.get(id);
		}
		var image = Image.fromFile(resolvePath(id));
		if (image != null && useCache && cache.enabled) {
			cache.image.set(id, image);
		}
		return image;
	}

	public static function getAudioBuffer(id:String, useCache:Bool = true):AudioBuffer {
		if (useCache && cache.enabled && cache.audio.exists(id)) {
			return cache.audio.get(id);
		}
		var buf = AudioBuffer.fromFile(resolvePath(id));
		if (buf != null && useCache && cache.enabled) {
			cache.audio.set(id, buf);
		}
		return buf;
	}

	public static function getFont(id:String, useCache:Bool = true):Font {
		if (useCache && cache.enabled && cache.font.exists(id)) {
			return cache.font.get(id);
		}
		var font = Font.fromFile(resolvePath(id));
		if (font != null && useCache && cache.enabled) {
			cache.font.set(id, font);
		}
		return font;
	}

	public static function loadBytes(id:String):Future<Bytes> {
		return new Future<Bytes>(() -> getBytes(id), true);
	}

	public static function loadText(id:String):Future<String> {
		return new Future<String>(() -> getText(id), true);
	}

	public static function loadImage(id:String, useCache:Bool = true):Future<Image> {
		if (useCache && cache.enabled && cache.image.exists(id)) {
			return Future.withValue(cache.image.get(id));
		}
		return Image.loadFromFile(resolvePath(id)).then(img -> {
			if (img != null && useCache && cache.enabled) {
				cache.image.set(id, img);
			}
			return Future.withValue(img);
		});
	}

	public static function loadAudioBuffer(id:String, useCache:Bool = true):Future<AudioBuffer> {
		if (useCache && cache.enabled && cache.audio.exists(id)) {
			return Future.withValue(cache.audio.get(id));
		}
		return AudioBuffer.loadFromFile(resolvePath(id)).then(buf -> {
			if (buf != null && useCache && cache.enabled) {
				cache.audio.set(id, buf);
			}
			return Future.withValue(buf);
		});
	}

	public static function loadFont(id:String, useCache:Bool = true):Future<Font> {
		if (useCache && cache.enabled && cache.font.exists(id)) {
			return Future.withValue(cache.font.get(id));
		}
		return Font.loadFromFile(resolvePath(id)).then(f -> {
			if (f != null && useCache && cache.enabled) {
				cache.font.set(id, f);
			}
			return Future.withValue(f);
		});
	}
}
