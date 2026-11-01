package puffpuff.snapshot;

import haxe.io.Bytes;

/**
 * BMP encoding of 8-bit RGBA pixels: 32 bits per pixel with the alpha channel, in a version 5 header (macOS reads that one and not version 4).
 */
class Bmp {
	static inline var HEADER = 14 + 124;

	/** `pixels` holds `width` x `height` RGBA pixels, rows top first, `stride` bytes apart. **/
	public static function encode(width:Int, height:Int, pixels:Bytes, ?stride:Int):Bytes {
		if (stride == null)
			stride = width * 4;
		var size = HEADER + width * height * 4;
		var out = Bytes.alloc(size);
		out.set(0, 0x42);
		out.set(1, 0x4D);
		out.setInt32(2, size);
		out.setInt32(10, HEADER);
		out.setInt32(14, 124);
		out.setInt32(18, width);
		out.setInt32(22, height);
		out.setUInt16(26, 1);
		out.setUInt16(28, 32);
		out.setInt32(30, 3); // BI_BITFIELDS
		out.setInt32(34, width * height * 4);
		out.setInt32(38, 2835);
		out.setInt32(42, 2835);
		out.setInt32(54, 0x00FF0000);
		out.setInt32(58, 0x0000FF00);
		out.setInt32(62, 0x000000FF);
		out.setInt32(66, 0xFF000000);
		out.setInt32(70, 0x73524742); // "sRGB"
		out.setInt32(122, 4); // intent: pictures
		// Rows run bottom first; each pixel is B, G, R, A.
		var at = HEADER;
		var y = height;
		while (y-- > 0) {
			var row = y * stride;
			for (x in 0...width) {
				var p = row + x * 4;
				out.set(at, pixels.get(p + 2));
				out.set(at + 1, pixels.get(p + 1));
				out.set(at + 2, pixels.get(p));
				out.set(at + 3, pixels.get(p + 3));
				at += 4;
			}
		}
		return out;
	}
}
