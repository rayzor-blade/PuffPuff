package lime.utils;

import haxe.io.Bytes;

class ArrayBufferView {
	public var buffer(default, null):Bytes;
	public var byteOffset(default, null):Int;
	public var byteLength(default, null):Int;
	public var length(default, null):Int;

	public function new(buffer:Bytes, byteOffset:Int = 0, byteLength:Null<Int> = null, bytesPerElement:Int = 1) {
		this.buffer = buffer;
		this.byteOffset = byteOffset;
		this.byteLength = byteLength != null ? byteLength : (buffer != null ? buffer.length - byteOffset : 0);
		this.length = Std.int(this.byteLength / bytesPerElement);
	}
}
