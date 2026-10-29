// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;

import ash.simd.Float32x4;

/**
 * 2D 3x2 affine transformation matrix accelerated with `ash-simd`.
 */
class Matrix3 {
	public var a:Float;
	public var b:Float;
	public var c:Float;
	public var d:Float;
	public var tx:Float;
	public var ty:Float;

	public function new(a:Float = 1.0, b:Float = 0.0, c:Float = 0.0, d:Float = 1.0, tx:Float = 0.0, ty:Float = 0.0) {
		this.a = a;
		this.b = b;
		this.c = c;
		this.d = d;
		this.tx = tx;
		this.ty = ty;
	}

	public inline function clone():Matrix3 {
		return new Matrix3(a, b, c, d, tx, ty);
	}

	public function concat(m:Matrix3):Void {
		// SIMD 2x2 multiplication + translation transform
		var col0 = Float32x4.make(m.a, m.b, m.a, m.b);
		var col1 = Float32x4.make(m.c, m.d, m.c, m.d);
		var abcd = col0 * Float32x4.make(a, a, c, c) + col1 * Float32x4.make(b, b, d, d);
		var tVec = Float32x4.make(m.a, m.b, 0.0, 0.0) * Float32x4.splat(tx)
			+ Float32x4.make(m.c, m.d, 0.0, 0.0) * Float32x4.splat(ty)
			+ Float32x4.make(m.tx, m.ty, 0.0, 0.0);

		a = abcd.x;
		b = abcd.y;
		c = abcd.z;
		d = abcd.w;
		tx = tVec.x;
		ty = tVec.y;
	}

	public inline function copyFrom(sourceMatrix3:Matrix3):Void {
		a = sourceMatrix3.a;
		b = sourceMatrix3.b;
		c = sourceMatrix3.c;
		d = sourceMatrix3.d;
		tx = sourceMatrix3.tx;
		ty = sourceMatrix3.ty;
	}

	public function createBox(scaleX:Float, scaleY:Float, rotation:Float = 0, tx:Float = 0, ty:Float = 0):Void {
		if (rotation != 0) {
			var cos = Math.cos(rotation);
			var sin = Math.sin(rotation);
			a = cos * scaleX;
			b = sin * scaleY;
			c = -sin * scaleX;
			d = cos * scaleY;
		} else {
			a = scaleX;
			b = 0;
			c = 0;
			d = scaleY;
		}
		this.tx = tx;
		this.ty = ty;
	}

	public function createGradientBox(width:Float, height:Float, rotation:Float = 0, tx:Float = 0, ty:Float = 0):Void {
		a = width / 1638.4;
		d = height / 1638.4;
		if (rotation != 0) {
			var cos = Math.cos(rotation);
			var sin = Math.sin(rotation);
			b = sin * d;
			c = -sin * a;
			a *= cos;
			d *= cos;
		} else {
			b = 0;
			c = 0;
		}
		this.tx = tx + width / 2;
		this.ty = ty + height / 2;
	}

	public inline function equals(matrix3:Matrix3):Bool {
		return matrix3 != null && tx == matrix3.tx && ty == matrix3.ty && a == matrix3.a && b == matrix3.b && c == matrix3.c && d == matrix3.d;
	}

	public inline function identity():Void {
		a = 1;
		b = 0;
		c = 0;
		d = 1;
		tx = 0;
		ty = 0;
	}

	public function invert():Matrix3 {
		var norm = a * d - b * c;
		if (norm == 0) {
			a = b = c = d = 0;
			tx = -tx;
			ty = -ty;
		} else {
			norm = 1.0 / norm;
			var a1 = d * norm;
			d = a * norm;
			a = a1;
			b *= -norm;
			c *= -norm;

			var tx1 = -a * tx - c * ty;
			ty = -b * tx - d * ty;
			tx = tx1;
		}
		return this;
	}

	public function rotate(theta:Float):Void {
		var cos = Math.cos(theta);
		var sin = Math.sin(theta);

		var a1 = a * cos - b * sin;
		b = a * sin + b * cos;
		a = a1;

		var c1 = c * cos - d * sin;
		d = c * sin + d * cos;
		c = c1;

		var tx1 = tx * cos - ty * sin;
		ty = tx * sin + ty * cos;
		tx = tx1;
	}

	public inline function scale(sx:Float, sy:Float):Void {
		a *= sx;
		b *= sy;
		c *= sx;
		d *= sy;
		tx *= sx;
		ty *= sy;
	}

	public inline function setRotation(theta:Float, scale:Float = 1):Void {
		a = Math.cos(theta) * scale;
		c = Math.sin(theta) * scale;
		b = -c;
		d = a;
	}

	public inline function setTo(aa:Float, ba:Float, ca:Float, da:Float, txa:Float, tya:Float):Void {
		a = aa;
		b = ba;
		c = ca;
		d = da;
		tx = txa;
		ty = tya;
	}

	public inline function deltaTransformVector(pos:Vector2, result:Vector2 = null):Vector2 {
		if (result == null) result = new Vector2();
		result.setTo(pos.x * a + pos.y * c, pos.x * b + pos.y * d);
		return result;
	}

	public inline function transformVector(pos:Vector2, result:Vector2 = null):Vector2 {
		if (result == null) result = new Vector2();
		result.setTo(pos.x * a + pos.y * c + tx, pos.x * b + pos.y * d + ty);
		return result;
	}

	public inline function translate(dx:Float, dy:Float):Void {
		tx += dx;
		ty += dy;
	}
}
