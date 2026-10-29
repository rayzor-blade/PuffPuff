package lime.utils;

import haxe.io.Bytes;

/**
 * Zero-copy UInt8Array backed by `haxe.io.Bytes` / `hl.Bytes`.
 */
abstract UInt8Array(ArrayBufferView) from ArrayBufferView to ArrayBufferView {
	public static inline var BYTES_PER_ELEMENT:Int = 1;

	public var buffer(get, never):Bytes;
	public var byteLength(get, never):Int;
	public var byteOffset(get, never):Int;
	public var length(get, never):Int;

	public inline function new(elements:Dynamic = null, byteOffset:Int = 0, len:Null<Int> = null) {
		if (Std.isOfType(elements, Int)) {
			var count:Int = cast elements;
			var bytes = Bytes.alloc(count);
			this = new ArrayBufferView(bytes, 0, count, BYTES_PER_ELEMENT);
		} else if (Std.isOfType(elements, Bytes)) {
			var bytes:Bytes = cast elements;
			var bLen = len != null ? len : bytes.length - byteOffset;
			this = new ArrayBufferView(bytes, byteOffset, bLen, BYTES_PER_ELEMENT);
		} else if (Std.isOfType(elements, Array)) {
			var arr:Array<Int> = cast elements;
			var count = len != null ? len : arr.length - byteOffset;
			var bytes = Bytes.alloc(count);
			for (i in 0...count) {
				bytes.set(i, arr[byteOffset + i] & 0xFF);
			}
			this = new ArrayBufferView(bytes, 0, count, BYTES_PER_ELEMENT);
		} else {
			this = new ArrayBufferView(Bytes.alloc(0), 0, 0, BYTES_PER_ELEMENT);
		}
	}

	@:arrayAccess
	public inline function get(index:Int):Int {
		return this.buffer.get(this.byteOffset + index);
	}

	@:arrayAccess
	public inline function set(index:Int, value:Int):Int {
		var v = value & 0xFF;
		this.buffer.set(this.byteOffset + index, v);
		return v;
	}

	public static inline function fromBytes(bytes:Bytes, byteOffset:Int = 0, len:Null<Int> = null):UInt8Array {
		return new UInt8Array(bytes, byteOffset, len);
	}

	public inline function toBytes():Bytes {
		if (this.byteOffset == 0 && this.byteLength == this.buffer.length) {
			return this.buffer;
		}
		return this.buffer.sub(this.byteOffset, this.byteLength);
	}

	private inline function get_buffer():Bytes return this.buffer;
	private inline function get_byteLength():Int return this.byteLength;
	private inline function get_byteOffset():Int return this.byteOffset;
	private inline function get_length():Int return this.length;
}
