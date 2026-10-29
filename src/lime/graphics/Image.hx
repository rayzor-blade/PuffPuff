// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.graphics;

import haxe.io.Bytes;
import lime.app.Future;
import lime.math.ColorMatrix;
import lime.math.Rectangle;
import lime.math.Vector2;
import lime.utils.BytePointer;
import puffpuff.snapshot.Png;
#if hl
import puffpuff.media.BitmapNative;
#end

class Image {
	public var buffer:ImageBuffer;
	public var data(get, set):Bytes;
	public var dirty:Bool;
	public var format(get, set):PixelFormat;
	public var height(default, null):Int;
	public var offsetX:Int;
	public var offsetY:Int;
	public var premultiplied(get, set):Bool;
	public var rect(get, never):Rectangle;
	public var transparent(get, set):Bool;
	public var type:ImageType;
	public var version:Int;
	public var width(default, null):Int;
	public var x:Float;
	public var y:Float;

	public function new(buffer:ImageBuffer = null, offsetX:Int = 0, offsetY:Int = 0, width:Int = -1, height:Int = -1, color:Null<Int> = null, type:ImageType = null) {
		this.offsetX = offsetX;
		this.offsetY = offsetY;
		this.width = width;
		this.height = height;
		this.type = type != null ? type : ImageType.DATA;
		this.version = 0;
		this.dirty = true;

		if (buffer == null) {
			if (this.width > 0 && this.height > 0) {
				var bytes = Bytes.alloc(this.width * this.height * 4);
				this.buffer = new ImageBuffer(bytes, this.width, this.height, 32, PixelFormat.RGBA32);
				if (color != null && color != 0) {
					fillBuffer(this.buffer, color);
				}
			}
		} else {
			this.buffer = buffer;
			if (this.width == -1) this.width = buffer.width;
			if (this.height == -1) this.height = buffer.height;
		}
	}

	private static function fillBuffer(buf:ImageBuffer, color:Int):Void {
		if (buf == null || buf.data == null) return;
		var a = (color >>> 24) & 0xFF;
		var r = (color >>> 16) & 0xFF;
		var g = (color >>> 8) & 0xFF;
		var b = color & 0xFF;
		var len = buf.width * buf.height * 4;
		var d = buf.data;
		var i = 0;
		while (i < len) {
			d.set(i, r);
			d.set(i + 1, g);
			d.set(i + 2, b);
			d.set(i + 3, a);
			i += 4;
		}
	}

	public function clone():Image {
		return new Image(buffer != null ? buffer.clone() : null, offsetX, offsetY, width, height, null, type);
	}

	public function getPixel(x:Int, y:Int, format:PixelFormat = null):Int {
		var c = getPixel32(x, y, format);
		return switch (format) {
			case ARGB32 | null: c & 0x00FFFFFF;
			default: (c >>> 8) & 0x00FFFFFF;
		};
	}

	public function getPixel32(x:Int, y:Int, format:PixelFormat = null):Int {
		if (buffer == null || buffer.data == null || x < 0 || y < 0 || x >= width || y >= height) return 0;
		var idx = ((y + offsetY) * buffer.width + (x + offsetX)) * 4;
		var d = buffer.data;
		var r = d.get(idx);
		var g = d.get(idx + 1);
		var b = d.get(idx + 2);
		var a = transparent ? d.get(idx + 3) : 0xFF;
		return switch (format) {
			case RGBA32: (r << 24) | (g << 16) | (b << 8) | a;
			case BGRA32: (b << 24) | (g << 16) | (r << 8) | a;
			default: (a << 24) | (r << 16) | (g << 8) | b;
		};
	}

	public function setPixel(x:Int, y:Int, color:Int, format:PixelFormat = null):Void {
		if (buffer == null || buffer.data == null || x < 0 || y < 0 || x >= width || y >= height) return;
		var idx = ((y + offsetY) * buffer.width + (x + offsetX)) * 4;
		var d = buffer.data;
		var r:Int, g:Int, b:Int;
		switch (format) {
			case RGBA32:
				r = (color >>> 24) & 0xFF;
				g = (color >>> 16) & 0xFF;
				b = (color >>> 8) & 0xFF;
			case BGRA32:
				b = (color >>> 24) & 0xFF;
				g = (color >>> 16) & 0xFF;
				r = (color >>> 8) & 0xFF;
			default:
				r = (color >>> 16) & 0xFF;
				g = (color >>> 8) & 0xFF;
				b = color & 0xFF;
		}
		d.set(idx, r);
		d.set(idx + 1, g);
		d.set(idx + 2, b);
		dirty = true;
		version++;
	}

	public function setPixel32(x:Int, y:Int, color:Int, format:PixelFormat = null):Void {
		if (buffer == null || buffer.data == null || x < 0 || y < 0 || x >= width || y >= height) return;
		var idx = ((y + offsetY) * buffer.width + (x + offsetX)) * 4;
		var d = buffer.data;
		var r:Int, g:Int, b:Int, a:Int;
		switch (format) {
			case RGBA32:
				r = (color >>> 24) & 0xFF;
				g = (color >>> 16) & 0xFF;
				b = (color >>> 8) & 0xFF;
				a = color & 0xFF;
			case BGRA32:
				b = (color >>> 24) & 0xFF;
				g = (color >>> 16) & 0xFF;
				r = (color >>> 8) & 0xFF;
				a = color & 0xFF;
			default:
				a = (color >>> 24) & 0xFF;
				r = (color >>> 16) & 0xFF;
				g = (color >>> 8) & 0xFF;
				b = color & 0xFF;
		}
		if (!transparent) a = 0xFF;
		d.set(idx, r);
		d.set(idx + 1, g);
		d.set(idx + 2, b);
		d.set(idx + 3, a);
		dirty = true;
		version++;
	}

	public function getPixels(rect:Rectangle, format:PixelFormat = null):Bytes {
		if (buffer == null || buffer.data == null) return null;
		var rx = Std.int(Math.max(0, rect.x));
		var ry = Std.int(Math.max(0, rect.y));
		var rw = Std.int(Math.min(width - rx, rect.width));
		var rh = Std.int(Math.min(height - ry, rect.height));
		if (rw <= 0 || rh <= 0) return Bytes.alloc(0);
		var out = Bytes.alloc(rw * rh * 4);
		var pos = 0;
		for (py in 0...rh) {
			for (px in 0...rw) {
				var c = getPixel32(rx + px, ry + py, format);
				out.set(pos++, (c >>> 24) & 0xFF);
				out.set(pos++, (c >>> 16) & 0xFF);
				out.set(pos++, (c >>> 8) & 0xFF);
				out.set(pos++, c & 0xFF);
			}
		}
		return out;
	}

	public function setPixels(rect:Rectangle, bytePointer:BytePointer, format:PixelFormat = null):Void {
		if (buffer == null || buffer.data == null || bytePointer == null || bytePointer.bytes == null) return;
		var rx = Std.int(Math.max(0, rect.x));
		var ry = Std.int(Math.max(0, rect.y));
		var rw = Std.int(Math.min(width - rx, rect.width));
		var rh = Std.int(Math.min(height - ry, rect.height));
		var src = bytePointer.bytes;
		var pos = bytePointer.offset;
		for (py in 0...rh) {
			for (px in 0...rw) {
				if (pos + 4 > src.length) break;
				var c = (src.get(pos) << 24) | (src.get(pos + 1) << 16) | (src.get(pos + 2) << 8) | src.get(pos + 3);
				pos += 4;
				setPixel32(rx + px, ry + py, c, format);
			}
		}
	}

	public function fillRect(rect:Rectangle, color:Int, format:PixelFormat = null):Void {
		if (buffer == null || buffer.data == null || rect == null) return;
		var rx = Std.int(Math.max(0, rect.x));
		var ry = Std.int(Math.max(0, rect.y));
		var rw = Std.int(Math.min(width - rx, rect.width));
		var rh = Std.int(Math.min(height - ry, rect.height));
		if (rw <= 0 || rh <= 0) return;

		var r:Int, g:Int, b:Int, a:Int;
		switch (format) {
			case RGBA32:
				r = (color >>> 24) & 0xFF;
				g = (color >>> 16) & 0xFF;
				b = (color >>> 8) & 0xFF;
				a = color & 0xFF;
			case BGRA32:
				b = (color >>> 24) & 0xFF;
				g = (color >>> 16) & 0xFF;
				r = (color >>> 8) & 0xFF;
				a = color & 0xFF;
			default:
				a = (color >>> 24) & 0xFF;
				r = (color >>> 16) & 0xFF;
				g = (color >>> 8) & 0xFF;
				b = color & 0xFF;
		}
		if (!transparent) a = 0xFF;
		var d = buffer.data;
		var bw = buffer.width;
		for (py in 0...rh) {
			var rowIdx = ((ry + py + offsetY) * bw + rx + offsetX) * 4;
			for (px in 0...rw) {
				var i = rowIdx + (px << 2);
				d.set(i, r);
				d.set(i + 1, g);
				d.set(i + 2, b);
				d.set(i + 3, a);
			}
		}
		dirty = true;
		version++;
	}

	public function copyPixels(sourceImage:Image, sourceRect:Rectangle, destPoint:Vector2, alphaImage:Image = null, alphaPoint:Vector2 = null, mergeAlpha:Bool = false):Void {
		if (buffer == null || buffer.data == null || sourceImage == null || sourceImage.buffer == null || sourceRect == null || destPoint == null) return;
		var sx = Std.int(sourceRect.x);
		var sy = Std.int(sourceRect.y);
		var sw = Std.int(sourceRect.width);
		var sh = Std.int(sourceRect.height);
		var dx = Std.int(destPoint.x);
		var dy = Std.int(destPoint.y);

		if (sx < 0) { sw += sx; dx -= sx; sx = 0; }
		if (sy < 0) { sh += sy; dy -= sy; sy = 0; }
		if (dx < 0) { sw += dx; sx -= dx; dx = 0; }
		if (dy < 0) { sh += dy; sy -= dy; dy = 0; }
		if (sx + sw > sourceImage.width) sw = sourceImage.width - sx;
		if (sy + sh > sourceImage.height) sh = sourceImage.height - sy;
		if (dx + sw > width) sw = width - dx;
		if (dy + sh > height) sh = height - dy;
		if (sw <= 0 || sh <= 0) return;

		var srcData = sourceImage.buffer.data;
		var dstData = buffer.data;
		var srcW = sourceImage.buffer.width;
		var dstW = buffer.width;

		for (py in 0...sh) {
			for (px in 0...sw) {
				var sIdx = ((sy + py + sourceImage.offsetY) * srcW + (sx + px + sourceImage.offsetX)) * 4;
				var dIdx = ((dy + py + offsetY) * dstW + (dx + px + offsetX)) * 4;
				var sr = srcData.get(sIdx);
				var sg = srcData.get(sIdx + 1);
				var sb = srcData.get(sIdx + 2);
				var sa = srcData.get(sIdx + 3);
				if (alphaImage != null && alphaImage.buffer != null) {
					var ax = (alphaPoint != null ? Std.int(alphaPoint.x) : 0) + px;
					var ay = (alphaPoint != null ? Std.int(alphaPoint.y) : 0) + py;
					if (ax >= 0 && ay >= 0 && ax < alphaImage.width && ay < alphaImage.height) {
						var aIdx = ((ay + alphaImage.offsetY) * alphaImage.buffer.width + (ax + alphaImage.offsetX)) * 4;
						sa = Std.int((sa * alphaImage.buffer.data.get(aIdx + 3) + 127) / 255);
					}
				}
				if (!mergeAlpha || sa == 255) {
					dstData.set(dIdx, sr);
					dstData.set(dIdx + 1, sg);
					dstData.set(dIdx + 2, sb);
					dstData.set(dIdx + 3, transparent ? sa : 255);
				} else if (sa > 0) {
					var dr = dstData.get(dIdx);
					var dg = dstData.get(dIdx + 1);
					var db = dstData.get(dIdx + 2);
					var da = dstData.get(dIdx + 3);
					var invA = 255 - sa;
					var outA = sa + Std.int((da * invA + 127) / 255);
					if (outA > 0) {
						dstData.set(dIdx, Std.int((sr * sa * 255 + dr * da * invA) / (outA * 255)));
						dstData.set(dIdx + 1, Std.int((sg * sa * 255 + dg * da * invA) / (outA * 255)));
						dstData.set(dIdx + 2, Std.int((sb * sa * 255 + db * da * invA) / (outA * 255)));
						dstData.set(dIdx + 3, transparent ? outA : 255);
					}
				}
			}
		}
		dirty = true;
		version++;
	}

	public function copyChannel(sourceImage:Image, sourceRect:Rectangle, destPoint:Vector2, sourceChannel:ImageChannel, destChannel:ImageChannel):Void {
		if (buffer == null || sourceImage == null || sourceImage.buffer == null) return;
		var sCh = switch (sourceChannel) { case RED: 0; case GREEN: 1; case BLUE: 2; case ALPHA: 3; };
		var dCh = switch (destChannel) { case RED: 0; case GREEN: 1; case BLUE: 2; case ALPHA: 3; };
		var sx = Std.int(sourceRect.x);
		var sy = Std.int(sourceRect.y);
		var sw = Std.int(sourceRect.width);
		var sh = Std.int(sourceRect.height);
		var dx = Std.int(destPoint.x);
		var dy = Std.int(destPoint.y);
		for (py in 0...sh) {
			for (px in 0...sw) {
				if (sx + px < 0 || sy + py < 0 || sx + px >= sourceImage.width || sy + py >= sourceImage.height) continue;
				if (dx + px < 0 || dy + py < 0 || dx + px >= width || dy + py >= height) continue;
				var sIdx = ((sy + py + sourceImage.offsetY) * sourceImage.buffer.width + (sx + px + sourceImage.offsetX)) * 4 + sCh;
				var dIdx = ((dy + py + offsetY) * buffer.width + (dx + px + offsetX)) * 4 + dCh;
				buffer.data.set(dIdx, sourceImage.buffer.data.get(sIdx));
			}
		}
		dirty = true;
		version++;
	}

	public function colorTransform(rect:Rectangle, colorMatrix:ColorMatrix):Void {
		if (buffer == null || buffer.data == null || rect == null || colorMatrix == null) return;
		var rTable = colorMatrix.getRedTable();
		var gTable = colorMatrix.getGreenTable();
		var bTable = colorMatrix.getBlueTable();
		var aTable = colorMatrix.getAlphaTable();
		var rx = Std.int(Math.max(0, rect.x));
		var ry = Std.int(Math.max(0, rect.y));
		var rw = Std.int(Math.min(width - rx, rect.width));
		var rh = Std.int(Math.min(height - ry, rect.height));
		var d = buffer.data;
		var bw = buffer.width;
		for (py in 0...rh) {
			var rowIdx = ((ry + py + offsetY) * bw + rx + offsetX) * 4;
			for (px in 0...rw) {
				var i = rowIdx + (px << 2);
				d.set(i, rTable[d.get(i)]);
				d.set(i + 1, gTable[d.get(i + 1)]);
				d.set(i + 2, bTable[d.get(i + 2)]);
				d.set(i + 3, aTable[d.get(i + 3)]);
			}
		}
		dirty = true;
		version++;
	}

	public function floodFill(x:Int, y:Int, color:Int, format:PixelFormat = null):Void {
		if (buffer == null || buffer.data == null || x < 0 || y < 0 || x >= width || y >= height) return;
		var target = getPixel32(x, y, format);
		if (target == color) return;
		var queue:Array<Int> = [x, y];
		while (queue.length > 0) {
			var cy = queue.pop();
			var cx = queue.pop();
			if (cx < 0 || cy < 0 || cx >= width || cy >= height) continue;
			if (getPixel32(cx, cy, format) != target) continue;
			setPixel32(cx, cy, color, format);
			queue.push(cx + 1); queue.push(cy);
			queue.push(cx - 1); queue.push(cy);
			queue.push(cx); queue.push(cy + 1);
			queue.push(cx); queue.push(cy - 1);
		}
	}

	public function scroll(x:Int, y:Int):Void {
		if (x == 0 && y == 0) return;
		var copy = clone();
		copyPixels(copy, new Rectangle(0, 0, width, height), new Vector2(x, y));
	}

	public function resize(newWidth:Int, newHeight:Int):Void {
		if (newWidth <= 0 || newHeight <= 0 || (newWidth == width && newHeight == height)) return;
		var out = Bytes.alloc(newWidth * newHeight * 4);
		if (buffer != null && buffer.data != null && width > 0 && height > 0) {
			var src = buffer.data;
			var bw = buffer.width;
			for (ny in 0...newHeight) {
				var sy = Std.int(ny * height / newHeight);
				for (nx in 0...newWidth) {
					var sx = Std.int(nx * width / newWidth);
					var sIdx = ((sy + offsetY) * bw + (sx + offsetX)) * 4;
					var dIdx = (ny * newWidth + nx) * 4;
					out.setInt32(dIdx, src.getInt32(sIdx));
				}
			}
		}
		buffer = new ImageBuffer(out, newWidth, newHeight, 32, PixelFormat.RGBA32);
		offsetX = 0;
		offsetY = 0;
		width = newWidth;
		height = newHeight;
		dirty = true;
		version++;
	}

	public function encode(format:ImageFileFormat = null, quality:Int = 90):Bytes {
		if (buffer == null || buffer.data == null) return null;
		return Png.encode(width, height, buffer.data, buffer.stride);
	}

	public static function fromBytes(bytes:Bytes):Image {
		if (bytes == null || bytes.length < 4) return null;
		#if hl
		var slot = BitmapNative.blinc_bitmap_decode(bytes.getData(), bytes.length);
		if (slot >= 0) {
			var w = BitmapNative.blinc_bitmap_size(slot, false);
			var h = BitmapNative.blinc_bitmap_size(slot, true);
			if (w > 0 && h > 0) {
				var pixels = Bytes.alloc(w * h * 4);
				var ok = BitmapNative.blinc_bitmap_resample(slot, w, h, 0, pixels.getData());
				BitmapNative.blinc_bitmap_release(slot);
				if (ok) {
					var buf = new ImageBuffer(pixels, w, h, 32, PixelFormat.RGBA32);
					return new Image(buf, 0, 0, w, h);
				}
			} else {
				BitmapNative.blinc_bitmap_release(slot);
			}
		}
		#end
		if (bytes.length >= 8 && bytes.get(0) == 0x89 && bytes.get(1) == 0x50) {
			var decoded = Png.decode(bytes);
			var buf = new ImageBuffer(decoded.pixels, decoded.width, decoded.height, 32, PixelFormat.RGBA32);
			return new Image(buf, 0, 0, decoded.width, decoded.height);
		}
		return null;
	}

	public static function fromFile(path:String):Image {
		if (path == null || !sys.FileSystem.exists(path)) return null;
		return fromBytes(sys.io.File.getBytes(path));
	}

	public static function loadFromBytes(bytes:Bytes):Future<Image> {
		return new Future<Image>(() -> fromBytes(bytes), true);
	}

	public static function loadFromFile(path:String):Future<Image> {
		return new Future<Image>(() -> fromFile(path), true);
	}

	private inline function get_rect():Rectangle return new Rectangle(0, 0, width, height);
	private inline function get_data():Bytes return buffer != null ? buffer.data : null;
	private inline function set_data(v:Bytes):Bytes {
		if (buffer != null) buffer.data = v;
		return v;
	}

	private inline function get_format():PixelFormat return buffer != null ? buffer.format : PixelFormat.RGBA32;
	private inline function set_format(v:PixelFormat):PixelFormat {
		if (buffer != null) buffer.format = v;
		return v;
	}

	private inline function get_premultiplied():Bool return buffer != null ? buffer.premultiplied : false;
	private inline function set_premultiplied(v:Bool):Bool {
		if (buffer != null) buffer.premultiplied = v;
		return v;
	}

	private inline function get_transparent():Bool return buffer != null ? buffer.transparent : true;
	private inline function set_transparent(v:Bool):Bool {
		if (buffer != null) buffer.transparent = v;
		return v;
	}
}
