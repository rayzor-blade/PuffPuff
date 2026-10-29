// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

import haxe.io.Bytes as HaxeBytes;
import lime.app.Future;

@:forward
abstract Bytes(HaxeBytes) from HaxeBytes to HaxeBytes {
	public inline function new(length:Int, bytesData:haxe.io.BytesData) {
		this = HaxeBytes.ofData(bytesData);
	}

	public static inline function alloc(length:Int):Bytes {
		return HaxeBytes.alloc(length);
	}

	public function compress(algorithm:CompressionAlgorithm):Bytes {
		if (this == null) return null;
		return switch (algorithm) {
			case DEFLATE | ZLIB | GZIP | LZMA:
				haxe.zip.Compress.run(this, 9);
		};
	}

	public function decompress(algorithm:CompressionAlgorithm):Bytes {
		if (this == null) return null;
		return switch (algorithm) {
			case DEFLATE | ZLIB | GZIP | LZMA:
				haxe.zip.Uncompress.run(this);
		};
	}

	public static inline function fastGet(b:haxe.io.BytesData, pos:Int):Int {
		return HaxeBytes.fastGet(b, pos);
	}

	public static function fromBytes(bytes:HaxeBytes):Bytes {
		return bytes;
	}

	public static function fromFile(path:String):Bytes {
		if (path == null || !sys.FileSystem.exists(path)) return null;
		return sys.io.File.getBytes(path);
	}

	public static function loadFromBytes(bytes:HaxeBytes):Future<Bytes> {
		return Future.withValue(fromBytes(bytes));
	}

	public static function loadFromFile(path:String):Future<Bytes> {
		return new Future<Bytes>(() -> fromFile(path), true);
	}

	public static inline function ofData(b:haxe.io.BytesData):Bytes {
		return HaxeBytes.ofData(b);
	}

	public static inline function ofString(s:String):Bytes {
		return HaxeBytes.ofString(s);
	}
}
