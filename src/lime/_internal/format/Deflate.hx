// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime._internal.format;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

/** Raw deflate streams: zlib's without its two-byte header and its Adler-32 trailer. **/
class Deflate
{
	public static function compress(bytes:Bytes):Bytes
	{
		var zlib = haxe.zip.Compress.run(bytes, 6);
		return zlib.sub(2, zlib.length - 6);
	}

	public static function decompress(bytes:Bytes):Bytes
	{
		var input = new haxe.zip.InflateImpl(new BytesInput(bytes), false, false);
		var out = new BytesOutput();
		var chunk = Bytes.alloc(65536);
		while (true)
		{
			var read = input.readBytes(chunk, 0, chunk.length);
			if (read > 0) out.writeBytes(chunk, 0, read);
			if (read < chunk.length) break;
		}
		return out.getBytes();
	}
}
