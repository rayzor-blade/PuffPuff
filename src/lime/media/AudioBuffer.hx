// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.media;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import lime.app.Future;
import lime.utils.UInt8Array;

/**
	Audio loaded from bytes or files. `data` holds the encoded file as read; decoding to PCM, and
	true streaming, are not done yet, so the `*Stream` variants load like their plain counterparts.
**/
class AudioBuffer {
	public var bitsPerSample:Int;
	public var channels:Int;
	public var data:UInt8Array;
	public var sampleRate:Int;
	public var src(get, set):Dynamic;

	@:noCompletion public var __srcPath:Null<String>;
	@:noCompletion private var __isDisposed:Bool = false;
	@:noCompletion private var __srcCustom:Dynamic;
	@:noCompletion private var __srcVorbisBytes:Dynamic;
	@:noCompletion private var __srcVorbisFile:Dynamic;
	@:noCompletion private var __srcVorbisPath:String;

	public function new() {
		bitsPerSample = 16;
		channels = 2;
		sampleRate = 44100;
	}

	public function dispose():Void {
		__isDisposed = true;
		__srcVorbisBytes = null;
		__srcVorbisFile = null;
		__srcVorbisPath = null;
		data = null;
	}

	public static function fromBase64(base64String:String):AudioBuffer {
		if (base64String == null) return null;
		return fromBytes(Base64.decode(base64String));
	}

	public static function fromBytes(bytes:Bytes):AudioBuffer {
		if (bytes == null) return null;
		var buffer = new AudioBuffer();
		buffer.data = UInt8Array.fromBytes(bytes);
		return buffer;
	}

	public static function fromBytesStream(bytes:Bytes):AudioBuffer {
		return fromBytes(bytes);
	}

	public static function fromFile(path:String):AudioBuffer {
		if (path == null) return null;
		var buffer = new AudioBuffer();
		buffer.__srcPath = path;
		if (sys.FileSystem.exists(path)) {
			buffer.data = UInt8Array.fromBytes(sys.io.File.getBytes(path));
		}
		return buffer;
	}

	public static function fromFileStream(path:String):AudioBuffer {
		return fromFile(path);
	}

	/** The first path in `paths` that exists, as `fromFile`; `null` if none does. **/
	public static function fromFiles(paths:Array<String>):AudioBuffer {
		if (paths != null) {
			for (path in paths) {
				if (path != null && sys.FileSystem.exists(path)) return fromFile(path);
			}
		}
		return null;
	}

	public static function fromFilesStream(paths:Array<String>):AudioBuffer {
		return fromFiles(paths);
	}

	/** Wraps an already-opened Vorbis file; `lime.media.vorbis` is not provided, so `vorbisFile` is untyped. **/
	public static function fromVorbisFile(vorbisFile:Dynamic):AudioBuffer {
		if (vorbisFile == null) return null;
		var buffer = new AudioBuffer();
		buffer.__srcVorbisFile = vorbisFile;
		return buffer;
	}

	public static function loadFromFile(path:String):Future<AudioBuffer> {
		return new Future<AudioBuffer>(() -> fromFile(path), true);
	}

	public static function loadFromFileStream(path:String):Future<AudioBuffer> {
		return loadFromFile(path);
	}

	public static function loadFromFiles(paths:Array<String>):Future<AudioBuffer> {
		return new Future<AudioBuffer>(() -> fromFiles(paths), true);
	}

	public static function loadFromFilesStream(paths:Array<String>):Future<AudioBuffer> {
		return loadFromFiles(paths);
	}

	@:noCompletion private function get_src():Dynamic {
		return __srcCustom;
	}

	@:noCompletion private function set_src(value:Dynamic):Dynamic {
		return __srcCustom = value;
	}
}
