// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.media;

import haxe.io.Bytes;
import lime.app.Future;
import lime.utils.UInt8Array;

class AudioBuffer {
	public var bitsPerSample:Int;
	public var channels:Int;
	public var data:UInt8Array;
	public var sampleRate:Int;

	@:noCompletion public var __srcPath:Null<String>;

	public function new() {
		bitsPerSample = 16;
		channels = 2;
		sampleRate = 44100;
	}

	public function dispose():Void {
		data = null;
	}

	public static function fromBytes(bytes:Bytes):AudioBuffer {
		if (bytes == null) return null;
		var buffer = new AudioBuffer();
		buffer.data = UInt8Array.fromBytes(bytes);
		return buffer;
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

	public static function loadFromFile(path:String):Future<AudioBuffer> {
		return new Future<AudioBuffer>(() -> fromFile(path), true);
	}
}
