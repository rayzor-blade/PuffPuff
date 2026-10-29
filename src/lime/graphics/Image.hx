package lime.graphics;

import haxe.io.Bytes;
import lime.app.Future;
import puffpuff.snapshot.Png;

class ImageBuffer {
	public var bitsPerPixel:Int;
	public var data:Bytes;
	public var format:Int;
	public var height:Int;
	public var premultiplied:Bool;
	public var transparent:Bool;
	public var width:Int;

	public function new(data:Bytes = null, width:Int = 0, height:Int = 0, bitsPerPixel:Int = 32, format:Int = 0) {
		this.data = data;
		this.width = width;
		this.height = height;
		this.bitsPerPixel = bitsPerPixel;
		this.format = format;
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

class Image {
	public var buffer:ImageBuffer;
	public var data(get, set):Bytes;
	public var dirty:Bool;
	public var format(get, set):Int;
	public var height(default, null):Int;
	public var offsetX:Int;
	public var offsetY:Int;
	public var premultiplied(get, set):Bool;
	public var transparent(get, set):Bool;
	public var version:Int;
	public var width(default, null):Int;
	public var x:Float;
	public var y:Float;

	public function new(buffer:ImageBuffer = null, offsetX:Int = 0, offsetY:Int = 0, width:Int = -1, height:Int = -1, color:Null<Int> = null, type:Dynamic = null) {
		this.offsetX = offsetX;
		this.offsetY = offsetY;
		this.width = width;
		this.height = height;
		this.version = 0;
		this.dirty = true;

		if (buffer == null) {
			if (this.width > 0 && this.height > 0) {
				var bytes = Bytes.alloc(this.width * this.height * 4);
				this.buffer = new ImageBuffer(bytes, this.width, this.height, 32, 0);
				if (color != null && color != 0) {
					fillRect(this.buffer, color);
				}
			}
		} else {
			this.buffer = buffer;
			if (this.width == -1) this.width = buffer.width;
			if (this.height == -1) this.height = buffer.height;
		}
	}

	private static function fillRect(buf:ImageBuffer, color:Int):Void {
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
		return new Image(buffer != null ? buffer.clone() : null, offsetX, offsetY, width, height);
	}

	public static function fromBytes(bytes:Bytes):Image {
		if (bytes == null || bytes.length < 8) return null;
		if (bytes.get(0) == 0x89 && bytes.get(1) == 0x50) {
			var decoded = Png.decode(bytes);
			var buf = new ImageBuffer(decoded.pixels, decoded.width, decoded.height, 32, 0);
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

	private inline function get_data():Bytes return buffer != null ? buffer.data : null;
	private inline function set_data(v:Bytes):Bytes {
		if (buffer != null) buffer.data = v;
		return v;
	}

	private inline function get_format():Int return buffer != null ? buffer.format : 0;
	private inline function set_format(v:Int):Int {
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
