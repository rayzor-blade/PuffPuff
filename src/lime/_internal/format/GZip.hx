// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime._internal.format;

import haxe.io.Bytes;
import haxe.io.BytesOutput;

/** gzip files: a ten-byte header, raw deflate, then the CRC-32 and size of the data. **/
class GZip
{
	public static function compress(bytes:Bytes):Bytes
	{
		var out = new BytesOutput();
		out.writeByte(0x1F);
		out.writeByte(0x8B);
		out.writeByte(8);
		out.writeByte(0);
		out.writeInt32(0);
		out.writeByte(0);
		out.writeByte(0xFF);
		out.write(Deflate.compress(bytes));
		out.writeInt32(haxe.crypto.Crc32.make(bytes));
		out.writeInt32(bytes.length);
		return out.getBytes();
	}

	public static function decompress(bytes:Bytes):Bytes
	{
		if (bytes.length < 18 || bytes.get(0) != 0x1F || bytes.get(1) != 0x8B || bytes.get(2) != 8) return null;

		var flags = bytes.get(3);
		var at = 10;
		if (flags & 4 != 0) at += 2 + bytes.getUInt16(at);
		if (flags & 8 != 0) while (bytes.get(at++) != 0) {}
		if (flags & 16 != 0) while (bytes.get(at++) != 0) {}
		if (flags & 2 != 0) at += 2;
		return Deflate.decompress(bytes.sub(at, bytes.length - at - 8));
	}
}
