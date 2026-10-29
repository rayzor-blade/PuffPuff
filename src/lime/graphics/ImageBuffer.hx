// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.graphics;

import haxe.io.Bytes;

class ImageBuffer {
	public var bitsPerPixel:Int;
	public var data:Bytes;
	public var format:PixelFormat;
	public var height:Int;
	public var premultiplied:Bool;
	public var transparent:Bool;
	public var width:Int;

	public function new(data:Bytes = null, width:Int = 0, height:Int = 0, bitsPerPixel:Int = 32, format:PixelFormat = null) {
		this.data = data;
		this.width = width;
		this.height = height;
		this.bitsPerPixel = bitsPerPixel;
		this.format = format != null ? format : PixelFormat.RGBA32;
		this.transparent = true;
		this.premultiplied = false;
	}

	public function clone():ImageBuffer {
		var copyData:Bytes = null;
		if (data != null) {
			copyData = Bytes.alloc(data.length);
			copyData.blit(0, data, 0, data.length);
		}
		var buffer = new ImageBuffer(copyData, width, height, bitsPerPixel, format);
		buffer.transparent = transparent;
		buffer.premultiplied = premultiplied;
		return buffer;
	}

	public var stride(get, never):Int;
	private inline function get_stride():Int {
		return width * Std.int(bitsPerPixel / 8);
	}
}
