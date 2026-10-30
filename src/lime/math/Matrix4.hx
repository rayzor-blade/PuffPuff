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
	 * Multiplies `this = this * rhs` with four-lane vectors. Memory is addressed through typed `hl.Bytes`
	 * (never `Dynamic`) and each weight is read straight from memory, so Ash keeps the whole chain in
	 * registers; the result is written back only after every source lane has been read.
	 */
	public function append(rhs:Matrix4):Void {
		var rhsArr:Float32Array = rhs;
		var pa:hl.Bytes = this.buffer;
		var pb:hl.Bytes = rhsArr.buffer;
		var oa = this.byteOffset;
		var ob = rhsArr.byteOffset;

		var c0 = Float32x4.load(pb, ob);
		var c1 = Float32x4.load(pb, ob + 16);
		var c2 = Float32x4.load(pb, ob + 32);
		var c3 = Float32x4.load(pb, ob + 48);

		var r0 = c0 * Float32x4.splat(pa.getF32(oa)) + c1 * Float32x4.splat(pa.getF32(oa + 4)) + c2 * Float32x4.splat(pa.getF32(oa + 8))
			+ c3 * Float32x4.splat(pa.getF32(oa + 12));
		var r1 = c0 * Float32x4.splat(pa.getF32(oa + 16)) + c1 * Float32x4.splat(pa.getF32(oa + 20)) + c2 * Float32x4.splat(pa.getF32(oa + 24))
			+ c3 * Float32x4.splat(pa.getF32(oa + 28));
		var r2 = c0 * Float32x4.splat(pa.getF32(oa + 32)) + c1 * Float32x4.splat(pa.getF32(oa + 36)) + c2 * Float32x4.splat(pa.getF32(oa + 40))
			+ c3 * Float32x4.splat(pa.getF32(oa + 44));
		var r3 = c0 * Float32x4.splat(pa.getF32(oa + 48)) + c1 * Float32x4.splat(pa.getF32(oa + 52)) + c2 * Float32x4.splat(pa.getF32(oa + 56))
			+ c3 * Float32x4.splat(pa.getF32(oa + 60));

		r0.store(pa, oa);
		r1.store(pa, oa + 16);
		r2.store(pa, oa + 32);
		r3.store(pa, oa + 48);
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
