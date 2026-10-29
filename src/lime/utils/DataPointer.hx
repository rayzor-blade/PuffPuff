// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

abstract DataPointer(Int) from Int to Int {
	public inline function new(value:Int = 0) {
		this = value;
	}

	@:from private static inline function fromBytes(bytes:haxe.io.Bytes):DataPointer {
		return new DataPointer(0);
	}

	@:from private static inline function fromArrayBufferView(view:ArrayBufferView):DataPointer {
		return new DataPointer(view != null ? view.byteOffset : 0);
	}

	@:from private static inline function fromBytesPointer(pointer:BytePointer):DataPointer {
		return new DataPointer(pointer != null ? pointer.offset : 0);
	}
}
