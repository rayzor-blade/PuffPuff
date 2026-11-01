import haxe.io.Bytes;
import lime.graphics.Image;
import lime.graphics.ImageFileFormat;
import lime.math.Rectangle;
import lime.utils.UInt8Array;

/**
 * Image.encode as PNG, BMP and JPEG on an image whose size is not a multiple of 8: PNG comes back exact through
 * Image.fromBytes, JPEG within a few levels, BMP is checked field by field. Files go to $PUFFPUFF_SNAPSHOT_DIR (or
 * .puffpuff/snapshots) as image-encode.{png,bmp,jpg} for other decoders. Prints "image encode checks passed" or throws.
 */
class ImageEncodeCheck {
	static inline var W = 37;
	static inline var H = 29;

	static function fail(message:String):Void {
		throw 'image encode check failed: $message';
	}

	/** A smooth ramp with a sharp square and a half-transparent band, so JPEG has both low and high frequencies. **/
	static function source():Image {
		var image = new Image(null, 0, 0, W, H, 0x00000000);
		var data = image.buffer.data;
		for (y in 0...H)
			for (x in 0...W) {
				var i = (y * W + x) * 4;
				var inSquare = x >= 10 && x < 20 && y >= 8 && y < 18;
				data[i] = inSquare ? 255 : Std.int(x * 255 / (W - 1));
				data[i + 1] = inSquare ? 32 : Std.int(y * 255 / (H - 1));
				data[i + 2] = inSquare ? 32 : 128;
				data[i + 3] = y >= 22 ? 128 : 255;
			}
		image.buffer.premultiplied = false;
		return image;
	}

	static function channel(image:Image, x:Int, y:Int, c:Int):Int
		return image.buffer.data[(y * image.width + x) * 4 + c];

	static function main():Void {
		var dir = Sys.getEnv("PUFFPUFF_SNAPSHOT_DIR");
		if (dir == null) dir = ".puffpuff/snapshots";
		sys.FileSystem.createDirectory(dir);
		var original = source();

		var png = original.encode(ImageFileFormat.PNG);
		sys.io.File.saveBytes('$dir/image-encode.png', png);
		var back = Image.fromBytes(png);
		if (back == null || back.width != W || back.height != H) fail("PNG did not decode to the same size");
		for (y in 0...H)
			for (x in 0...W)
				for (c in 0...4)
					if (channel(back, x, y, c) != channel(original, x, y, c)) fail('PNG differs at $x,$y channel $c');

		var bmp = original.encode(ImageFileFormat.BMP);
		sys.io.File.saveBytes('$dir/image-encode.bmp', bmp);
		if (bmp == null || bmp.getString(0, 2) != "BM") fail("BMP has no signature");
		if (bmp.getInt32(2) != bmp.length) fail('BMP size field ${bmp.getInt32(2)} for ${bmp.length} bytes');
		if (bmp.getInt32(18) != W || bmp.getInt32(22) != H || bmp.getUInt16(28) != 32) fail("BMP size or depth wrong");
		// Rows are stored bottom first as B, G, R, A.
		var offset = bmp.getInt32(10);
		for (probe in [[0, 0], [15, 12], [W - 1, H - 1], [5, 25]]) {
			var x = probe[0], y = probe[1];
			var at = offset + ((H - 1 - y) * W + x) * 4;
			var got = [bmp.get(at + 2), bmp.get(at + 1), bmp.get(at), bmp.get(at + 3)];
			for (c in 0...4)
				if (got[c] != channel(original, x, y, c)) fail('BMP pixel $x,$y is $got');
		}

		for (quality in [90, 50]) {
			var jpeg = original.encode(ImageFileFormat.JPEG, quality);
			sys.io.File.saveBytes('$dir/image-encode-q$quality.jpg', jpeg);
			var decoded = Image.fromBytes(jpeg);
			if (decoded == null || decoded.width != W || decoded.height != H) fail('JPEG q$quality did not decode to the same size');
			// Alpha is dropped: compare against the premultiplied (over black) colors.
			var sum = 0.0;
			for (y in 0...H)
				for (x in 0...W) {
					var a = channel(original, x, y, 3) / 255;
					for (c in 0...3)
						sum += Math.abs(channel(decoded, x, y, c) - channel(original, x, y, c) * a);
				}
			var mean = sum / (W * H * 3);
			Sys.println('JPEG q$quality: ${jpeg.length} bytes, mean error ${Math.round(mean * 100) / 100}');
			if (mean > (quality >= 90 ? 6 : 10)) fail('JPEG q$quality mean error $mean');
		}
		var large = new Image(null, 0, 0, 512, 512, 0xFF336699);
		for (format in [ImageFileFormat.PNG, ImageFileFormat.BMP, ImageFileFormat.JPEG]) {
			var start = haxe.Timer.stamp();
			var bytes = large.encode(format);
			Sys.println('$format 512x512: ${bytes.length} bytes, ${Math.round((haxe.Timer.stamp() - start) * 1000)} ms');
		}
		Sys.println("image encode checks passed");
	}
}
