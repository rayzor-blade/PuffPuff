package lime.utils;

import haxe.io.Bytes;
import lime.app.Event;
import lime.app.Future;
import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;

enum abstract AssetType(String) from String to String {
	public var BINARY = "BINARY";
	public var FONT = "FONT";
	public var IMAGE = "IMAGE";
	public var MUSIC = "MUSIC";
	public var SOUND = "SOUND";
	public var TEMPLATE = "TEMPLATE";
	public var TEXT = "TEXT";
}

class AssetCache {
	public var audio:Map<String, AudioBuffer>;
	public var enabled:Bool = true;
	public var font:Map<String, Font>;
	public var image:Map<String, Image>;
	public var version:Int = 1;

	public function new() {
		audio = new Map<String, AudioBuffer>();
		font = new Map<String, Font>();
		image = new Map<String, Image>();
	}

	public function clear(prefix:String = null):Void {
		if (prefix == null) {
			audio.clear();
			font.clear();
			image.clear();
		} else {
			for (k in audio.keys()) if (StringTools.startsWith(k, prefix)) audio.remove(k);
			for (k in font.keys()) if (StringTools.startsWith(k, prefix)) font.remove(k);
			for (k in image.keys()) if (StringTools.startsWith(k, prefix)) image.remove(k);
		}
	}
}

/**
 * Lime Assets facade backed by `ash-future`, `hlavi`, and `puffpuff.snapshot.Png`.
 */
class Assets {
	public static var cache:AssetCache = new AssetCache();
	public static var onChange = new Event<Void->Void>();

	private static var __assetPaths:Map<String, String> = new Map<String, String>();

	public static function registerPath(id:String, path:String):Void {
		__assetPaths.set(id, path);
	}

	private static function resolvePath(id:String):String {
		if (__assetPaths.exists(id)) return __assetPaths.get(id);
		return id;
	}

	public static function exists(id:String, type:AssetType = null):Bool {
		var path = resolvePath(id);
		return sys.FileSystem.exists(path);
	}

	public static function getBytes(id:String):Bytes {
		var path = resolvePath(id);
		if (!sys.FileSystem.exists(path)) return null;
		return sys.io.File.getBytes(path);
	}

	public static function getText(id:String):String {
		var path = resolvePath(id);
		if (!sys.FileSystem.exists(path)) return null;
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

