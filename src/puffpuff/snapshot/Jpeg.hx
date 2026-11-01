package puffpuff.snapshot;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;

/**
 * Baseline JPEG encoding of 8-bit RGBA pixels: YCbCr without chroma subsampling and the standard Huffman tables.
 * The alpha channel is dropped, so premultiplied pixels land on black.
 */
class Jpeg {
	static final ZIGZAG = [0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63];
	static final LUMA_QUANT = [
		16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55, 14, 13, 16, 24, 40, 57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62, 18, 22, 37, 56, 68,
		109, 103, 77, 24, 35, 55, 64, 81, 104, 113, 92, 49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112, 100, 103, 99
	];
	static final CHROMA_QUANT = [
		17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99, 24, 26, 56, 99, 99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
		99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99
	];
	static final LUMA_DC_LENGTHS = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];
	static final LUMA_DC_VALUES = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
	static final CHROMA_DC_LENGTHS = [0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0];
	static final CHROMA_DC_VALUES = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
	static final LUMA_AC_LENGTHS = [0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 125];
	static final LUMA_AC_VALUES = [1, 2, 3, 0, 4, 17, 5, 18, 33, 49, 65, 6, 19, 81, 97, 7, 34, 113, 20, 50, 129, 145, 161, 8, 35, 66, 177, 193, 21, 82, 209, 240, 36, 51, 98, 114, 130, 9, 10, 22, 23, 24, 25, 26, 37, 38, 39, 40, 41, 42, 52, 53, 54, 55, 56, 57, 58, 67, 68, 69, 70, 71, 72, 73, 74, 83, 84, 85, 86, 87, 88, 89, 90, 99, 100, 101, 102, 103, 104, 105, 106, 115, 116, 117, 118, 119, 120, 121, 122, 131, 132, 133, 134, 135, 136, 137, 138, 146, 147, 148, 149, 150, 151, 152, 153, 154, 162, 163, 164, 165, 166, 167, 168, 169, 170, 178, 179, 180, 181, 182, 183, 184, 185, 186, 194, 195, 196, 197, 198, 199, 200, 201, 202, 210, 211, 212, 213, 214, 215, 216, 217, 218, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250];
	static final CHROMA_AC_LENGTHS = [0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 119];
	static final CHROMA_AC_VALUES = [0, 1, 2, 3, 17, 4, 5, 33, 49, 6, 18, 65, 81, 7, 97, 113, 19, 34, 50, 129, 8, 20, 66, 145, 161, 177, 193, 9, 35, 51, 82, 240, 21, 98, 114, 209, 10, 22, 36, 52, 225, 37, 241, 23, 24, 25, 26, 38, 39, 40, 41, 42, 53, 54, 55, 56, 57, 58, 67, 68, 69, 70, 71, 72, 73, 74, 83, 84, 85, 86, 87, 88, 89, 90, 99, 100, 101, 102, 103, 104, 105, 106, 115, 116, 117, 118, 119, 120, 121, 122, 130, 131, 132, 133, 134, 135, 136, 137, 138, 146, 147, 148, 149, 150, 151, 152, 153, 154, 162, 163, 164, 165, 166, 167, 168, 169, 170, 178, 179, 180, 181, 182, 183, 184, 185, 186, 194, 195, 196, 197, 198, 199, 200, 201, 202, 210, 211, 212, 213, 214, 215, 216, 217, 218, 226, 227, 228, 229, 230, 231, 232, 233, 234, 242, 243, 244, 245, 246, 247, 248, 249, 250];

	/** `pixels` holds `width` x `height` RGBA pixels, rows top first, `stride` bytes apart. `quality` is 1 to 100. **/
	public static function encode(width:Int, height:Int, pixels:Bytes, ?stride:Int, quality:Int = 90):Bytes {
		if (stride == null)
			stride = width * 4;
		var q = quality < 1 ? 1 : quality > 100 ? 100 : quality;
		var scale = q < 50 ? 5000 / q : 200 - q * 2;
		var lumaQuant = quantTable(LUMA_QUANT, scale), chromaQuant = quantTable(CHROMA_QUANT, scale);
		var out = new BytesBuffer();
		inline function u8(v:Int)
			out.addByte(v & 0xFF);
		inline function u16(v:Int) {
			u8(v >> 8);
			u8(v);
		}
		u16(0xFFD8);
		// JFIF header, no thumbnail.
		u16(0xFFE0);
		u16(16);
		for (c in "JFIF".split(""))
			u8(c.charCodeAt(0));
		u8(0);
		u16(0x0101);
		u8(0);
		u16(1);
		u16(1);
		u8(0);
		u8(0);
		for (t in 0...2) {
			u16(0xFFDB);
			u16(67);
			u8(t);
			var table = t == 0 ? lumaQuant : chromaQuant;
			for (i in 0...64)
				u8(table[ZIGZAG[i]]);
		}
		u16(0xFFC0);
		u16(17);
		u8(8);
		u16(height);
		u16(width);
		u8(3);
		for (c in 0...3) {
			u8(c + 1);
			u8(0x11);
			u8(c == 0 ? 0 : 1);
		}
		huffmanHeader(out, 0x00, LUMA_DC_LENGTHS, LUMA_DC_VALUES);
		huffmanHeader(out, 0x10, LUMA_AC_LENGTHS, LUMA_AC_VALUES);
		huffmanHeader(out, 0x01, CHROMA_DC_LENGTHS, CHROMA_DC_VALUES);
		huffmanHeader(out, 0x11, CHROMA_AC_LENGTHS, CHROMA_AC_VALUES);
		u16(0xFFDA);
		u16(12);
		u8(3);
		for (c in 0...3) {
			u8(c + 1);
			u8(c == 0 ? 0x00 : 0x11);
		}
		u8(0);
		u8(63);
		u8(0);

		var bits = new BitWriter(out);
		var lumaDc = codes(LUMA_DC_LENGTHS, LUMA_DC_VALUES), lumaAc = codes(LUMA_AC_LENGTHS, LUMA_AC_VALUES);
		var chromaDc = codes(CHROMA_DC_LENGTHS, CHROMA_DC_VALUES), chromaAc = codes(CHROMA_AC_LENGTHS, CHROMA_AC_VALUES);
		var cosines = cosineMatrix();
		var planes = [for (_ in 0...3) [for (_ in 0...64) 0.0]];
		var block = [for (_ in 0...64) 0.0];
		var temp = [for (_ in 0...64) 0.0];
		var zigzag = [for (_ in 0...64) 0];
		var previous = [0, 0, 0];
		var blocksX = (width + 7) >> 3, blocksY = (height + 7) >> 3;
		for (by in 0...blocksY)
			for (bx in 0...blocksX) {
				// Level-shifted YCbCr of the 8 x 8 pixels, edge pixels repeated past the image.
				for (y in 0...8) {
					var sy = by * 8 + y;
					if (sy >= height)
						sy = height - 1;
					for (x in 0...8) {
						var sx = bx * 8 + x;
						if (sx >= width)
							sx = width - 1;
						var at = sy * stride + sx * 4;
						var r = pixels.get(at), g = pixels.get(at + 1), b = pixels.get(at + 2);
						var i = y * 8 + x;
						planes[0][i] = 0.299 * r + 0.587 * g + 0.114 * b - 128;
						planes[1][i] = -0.168736 * r - 0.331264 * g + 0.5 * b;
						planes[2][i] = 0.5 * r - 0.418688 * g - 0.081312 * b;
					}
				}
				for (c in 0...3) {
					var plane = planes[c];
					var quant = c == 0 ? lumaQuant : chromaQuant;
					// Rows, then columns: F = C f C^T.
					for (y in 0...8)
						for (u in 0...8) {
							var sum = 0.0;
							for (x in 0...8)
								sum += cosines[u * 8 + x] * plane[y * 8 + x];
							temp[y * 8 + u] = sum;
						}
					for (u in 0...8)
						for (v in 0...8) {
							var sum = 0.0;
							for (y in 0...8)
								sum += cosines[v * 8 + y] * temp[y * 8 + u];
							block[v * 8 + u] = sum;
						}
					for (i in 0...64) {
						var natural = ZIGZAG[i];
						zigzag[i] = Math.round(block[natural] / quant[natural]);
					}
					previous[c] = encodeBlock(bits, zigzag, previous[c], c == 0 ? lumaDc : chromaDc, c == 0 ? lumaAc : chromaAc);
				}
			}
		bits.flush();
		u16(0xFFD9);
		return out.getBytes();
	}

	static function quantTable(base:Array<Int>, scale:Float):Array<Int> {
		var out = [];
		for (b in base) {
			var v = Std.int((b * scale + 50) / 100);
			out.push(v < 1 ? 1 : v > 255 ? 255 : v);
		}
		return out;
	}

	/** `C[u * 8 + x]`: the orthonormal 8-point DCT basis. **/
	static function cosineMatrix():Array<Float> {
		var out = [];
		for (u in 0...8)
			for (x in 0...8)
				out.push((u == 0 ? Math.sqrt(0.125) : 0.5) * Math.cos((2 * x + 1) * u * Math.PI / 16));
		return out;
	}

	static function huffmanHeader(out:BytesBuffer, id:Int, lengths:Array<Int>, values:Array<Int>):Void {
		out.addByte(0xFF);
		out.addByte(0xC4);
		var size = 2 + 1 + 16 + values.length;
		out.addByte(size >> 8);
		out.addByte(size & 0xFF);
		out.addByte(id);
		for (l in lengths)
			out.addByte(l);
		for (v in values)
			out.addByte(v);
	}

	/** Canonical codes: `[value]` is `code << 8 | length`, zero for values the table lacks. **/
	static function codes(lengths:Array<Int>, values:Array<Int>):Array<Int> {
		var out = [for (_ in 0...256) 0];
		var code = 0, k = 0;
		for (length in 1...17) {
			for (_ in 0...lengths[length - 1])
				out[values[k++]] = (code++ << 8) | length;
			code <<= 1;
		}
		return out;
	}

	static inline function category(v:Int):Int {
		var a = v < 0 ? -v : v, n = 0;
		while (a != 0) {
			n++;
			a >>= 1;
		}
		return n;
	}

	/** Writes one block and returns its DC value, the next block's predictor. **/
	static function encodeBlock(bits:BitWriter, zigzag:Array<Int>, previousDc:Int, dc:Array<Int>, ac:Array<Int>):Int {
		var diff = zigzag[0] - previousDc;
		var size = category(diff);
		bits.write(dc[size] >> 8, dc[size] & 0xFF);
		if (size > 0)
			bits.write(diff < 0 ? diff - 1 : diff, size);
		var run = 0;
		for (i in 1...64) {
			var v = zigzag[i];
			if (v == 0) {
				run++;
				continue;
			}
			while (run > 15) {
				bits.write(ac[0xF0] >> 8, ac[0xF0] & 0xFF);
				run -= 16;
			}
			var s = category(v);
			var symbol = (run << 4) | s;
			bits.write(ac[symbol] >> 8, ac[symbol] & 0xFF);
			bits.write(v < 0 ? v - 1 : v, s);
			run = 0;
		}
		if (run > 0)
			bits.write(ac[0] >> 8, ac[0] & 0xFF);
		return zigzag[0];
	}
}

/** Entropy-coded bits, most significant first, with a zero byte after each 0xFF. **/
private class BitWriter {
	final out:BytesBuffer;
	var buffer = 0;
	var count = 0;

	public function new(out:BytesBuffer)
		this.out = out;

	/** The low `length` bits of `value`. **/
	public inline function write(value:Int, length:Int):Void {
		buffer = (buffer << length) | (value & ((1 << length) - 1));
		count += length;
		while (count >= 8) {
			count -= 8;
			var b = (buffer >> count) & 0xFF;
			out.addByte(b);
			if (b == 0xFF)
				out.addByte(0);
		}
		buffer &= (1 << count) - 1;
	}

	/** Pads the last byte with ones. **/
	public function flush():Void {
		if (count > 0)
			write(0x7F, 8 - count);
	}
}
