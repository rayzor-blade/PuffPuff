// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

class BytePointer {
	public var bytes:haxe.io.Bytes;
	public var offset:Int;

	public function new(bytes:haxe.io.Bytes = null, offset:Int = 0) {
		this.bytes = bytes;
		this.offset = offset;
	}

	public inline function set(bytes:haxe.io.Bytes = null, bufferView:ArrayBufferView = null, buffer:haxe.io.Bytes = null, offset:Null<Int> = null):Void {
		if (buffer != null) bytes = buffer;
		if (bytes != null || bufferView == null) {
			this.bytes = bytes;
			this.offset = offset != null ? offset : 0;
		} else {
			this.bytes = bufferView.buffer;
			this.offset = (offset != null ? offset : 0) + bufferView.byteOffset;
		}
	}
}
