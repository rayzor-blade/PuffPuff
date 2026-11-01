// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime._internal.format;

import haxe.io.Bytes;

/** zlib streams, with the standard library's deflate. **/
class Zlib
{
	public static function compress(bytes:Bytes):Bytes
	{
		return haxe.zip.Compress.run(bytes, 6);
	}

	public static function decompress(bytes:Bytes):Bytes
	{
		return haxe.zip.Uncompress.run(bytes);
	}
}
