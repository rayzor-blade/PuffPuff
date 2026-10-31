package puffpuff.gpu;

import haxe.io.Bytes;
import lime.math.Matrix4;
import puffpuff.gpu.WgpuContext3D.WgpuTexture;

/**
 * Collects textured triangles (position, texture coordinate, perspective term and 8-bit color: 24 bytes per vertex) and draws them in one call.
 */
class TriangleBatcher {
	public static inline var BYTES = 24;

	public var context3D(default, null):WgpuContext3D;
	public var texture:Null<WgpuTexture>;
	public var repeat:Bool = false;
	public var bytes(default, null):Bytes;
	public var length(default, null):Int = 0;

	public function new(context3D:WgpuContext3D, initialVertices:Int = 3072) {
		this.context3D = context3D;
		bytes = Bytes.alloc(initialVertices * BYTES);
	}

	public inline function begin(texture:WgpuTexture, repeat:Bool):Void {
		this.texture = texture;
		this.repeat = repeat;
		length = 0;
	}

	/** `u` and `v` are the texture coordinates, `t` the perspective term (1 when flat), `rgba` the tint with red in the low byte. **/
	public inline function vertex(x:Float, y:Float, u:Float, v:Float, t:Float, rgba:Int):Void {
		if (length + BYTES > bytes.length) grow();
		var buf = bytes, o = length;
		buf.setFloat(o, x);
		buf.setFloat(o + 4, y);
		buf.setFloat(o + 8, u * t);
		buf.setFloat(o + 12, v * t);
		buf.setFloat(o + 16, t);
		buf.setInt32(o + 20, rgba);
		length += BYTES;
	}

	function grow():Void {
		var next = Bytes.alloc(bytes.length * 2);
		next.blit(0, bytes, 0, length);
		bytes = next;
	}

	public function flush(projection:Matrix4):Void {
		if (length == 0 || texture == null) return;
		context3D.drawTexturedTriangles(texture, repeat, projection, bytes, length);
		length = 0;
	}
}
