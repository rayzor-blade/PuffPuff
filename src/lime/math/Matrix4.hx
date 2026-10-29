// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;

import ash.simd.Float32x4;
import lime.utils.Float32Array;

/**
 * 4x4 Matrix backed by `Float32Array` (`hl.Bytes`) and accelerated via `ash-simd`.
 */
abstract Matrix4(Float32Array) from Float32Array to Float32Array {
	public var buffer(get, never):haxe.io.Bytes;
	public var byteOffset(get, never):Int;
	public var byteLength(get, never):Int;

	private inline function get_buffer():haxe.io.Bytes return this.buffer;
	private inline function get_byteOffset():Int return this.byteOffset;
	private inline function get_byteLength():Int return this.byteLength;

	public inline function new(data:Float32Array = null) {
		if (data != null) {
			this = data;
		} else {
			this = new Float32Array(16);
			identity();
		}
	}

	public inline function identity():Void {
		var b = this.buffer;
		var o = this.byteOffset;
		for (i in 0...16) b.setFloat(o + (i << 2), 0.0);
		b.setFloat(o, 1.0);
		b.setFloat(o + 20, 1.0);
		b.setFloat(o + 40, 1.0);
		b.setFloat(o + 60, 1.0);
	}

	public inline function clone():Matrix4 {
		var copy = new Float32Array(16);
		copy.buffer.blit(copy.byteOffset, this.buffer, this.byteOffset, 64);
		return new Matrix4(copy);
	}

	/**
	 * Multiplies `this = this * rhs` using SIMD 4-lane vector operations.
	 */
	public function append(rhs:Matrix4):Void {
		var rhsArr:Float32Array = rhs;
		var bA = @:privateAccess (this.buffer : Dynamic).b;
		var bB = @:privateAccess (rhsArr.buffer : Dynamic).b;
		var oA = this.byteOffset;
		var oB = rhsArr.byteOffset;

		var col0 = Float32x4.load(bB, oB);
		var col1 = Float32x4.load(bB, oB + 16);
		var col2 = Float32x4.load(bB, oB + 32);
		var col3 = Float32x4.load(bB, oB + 48);

		var a0 = Float32x4.load(bA, oA);
		var a1 = Float32x4.load(bA, oA + 16);
		var a2 = Float32x4.load(bA, oA + 32);
		var a3 = Float32x4.load(bA, oA + 48);

		var r0 = col0 * Float32x4.splat(a0.x) + col1 * Float32x4.splat(a0.y) + col2 * Float32x4.splat(a0.z) + col3 * Float32x4.splat(a0.w);
		var r1 = col0 * Float32x4.splat(a1.x) + col1 * Float32x4.splat(a1.y) + col2 * Float32x4.splat(a1.z) + col3 * Float32x4.splat(a1.w);
		var r2 = col0 * Float32x4.splat(a2.x) + col1 * Float32x4.splat(a2.y) + col2 * Float32x4.splat(a2.z) + col3 * Float32x4.splat(a2.w);
		var r3 = col0 * Float32x4.splat(a3.x) + col1 * Float32x4.splat(a3.y) + col2 * Float32x4.splat(a3.z) + col3 * Float32x4.splat(a3.w);

		r0.store(bA, oA);
		r1.store(bA, oA + 16);
		r2.store(bA, oA + 32);
		r3.store(bA, oA + 48);
	}

	public function createOrtho(x0:Float, x1:Float, y0:Float, y1:Float, zNear:Float, zFar:Float):Void {
		var sx = 2.0 / (x1 - x0);
		var sy = 2.0 / (y1 - y0);
		var sz = 1.0 / (zFar - zNear);

		var tx = -(x1 + x0) / (x1 - x0);
		var ty = -(y1 + y0) / (y1 - y0);
		var tz = -zNear / (zFar - zNear);

		identity();
		// Stored so that HXSL/WGSL `vec4(pos, 0, 1) * matrix` (where WGSL `v * M` computes dot(v, col_i))
		// transforms x' = x*sx + tx, y' = y*sy + ty, z' = z*sz + tz, w' = 1:
		// Col 0: (sx, 0, 0, tx), Col 1: (0, sy, 0, ty), Col 2: (0, 0, sz, tz), Col 3: (0, 0, 0, 1)
		this[0] = sx;
		this[3] = tx;
		this[5] = sy;
		this[7] = ty;
		this[10] = sz;
		this[11] = tz;
		this[15] = 1.0;
	}

	@:arrayAccess
	public inline function get(index:Int):Float {
		return this[index];
	}

	@:arrayAccess
	public inline function set(index:Int, value:Float):Float {
		return this[index] = value;
	}
}
