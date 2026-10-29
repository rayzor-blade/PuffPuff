// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

import haxe.io.Bytes;

abstract Float64Array(ArrayBufferView) from ArrayBufferView to ArrayBufferView {
	public static inline var BYTES_PER_ELEMENT:Int = 8;

	public var buffer(get, never):Bytes;
	public var byteLength(get, never):Int;
	public var byteOffset(get, never):Int;
	public var length(get, never):Int;

	public inline function new(elements:Dynamic = null, byteOffset:Int = 0, len:Null<Int> = null) {
		if (Std.isOfType(elements, Int)) {
			var count:Int = cast elements;
			var bytes = Bytes.alloc(count * BYTES_PER_ELEMENT);
			this = new ArrayBufferView(bytes, 0, bytes.length, BYTES_PER_ELEMENT);
		} else if (Std.isOfType(elements, Bytes)) {
			var bytes:Bytes = cast elements;
			var bLen = len != null ? len * BYTES_PER_ELEMENT : bytes.length - byteOffset;
			this = new ArrayBufferView(bytes, byteOffset, bLen, BYTES_PER_ELEMENT);
		} else if (Std.isOfType(elements, Array)) {
			var arr:Array<Float> = cast elements;
			var count = len != null ? len : arr.length - byteOffset;
			var bytes = Bytes.alloc(count * BYTES_PER_ELEMENT);
			for (i in 0...count) {
				bytes.setDouble(i * BYTES_PER_ELEMENT, arr[byteOffset + i]);
			}
			this = new ArrayBufferView(bytes, 0, bytes.length, BYTES_PER_ELEMENT);
		} else {
			this = new ArrayBufferView(Bytes.alloc(0), 0, 0, BYTES_PER_ELEMENT);
		}
	}

	@:arrayAccess
	public inline function get(index:Int):Float {
		return this.buffer.getDouble(this.byteOffset + (index << 3));
	}

	@:arrayAccess
	public inline function set(index:Int, value:Float):Float {
		this.buffer.setDouble(this.byteOffset + (index << 3), value);
		return value;
	}

	private inline function get_buffer():Bytes return this.buffer;
	private inline function get_byteLength():Int return this.byteLength;
	private inline function get_byteOffset():Int return this.byteOffset;
	private inline function get_length():Int return this.length;
}
