// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;


/**
 * 2D 3x2 affine transformation matrix.
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
		// Plain double arithmetic: faster than four-lane vectors for six object fields, and exact.
		var oa = a, ob = b, oc = c, od = d, otx = tx, oty = ty;
		a = oa * m.a + ob * m.c;
		b = oa * m.b + ob * m.d;
		c = oc * m.a + od * m.c;
		d = oc * m.b + od * m.d;
		tx = otx * m.a + oty * m.c + m.tx;
		ty = otx * m.b + oty * m.d + m.ty;
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

	/**
		Copies the `x` and `y` components from a `Vector4` instance
		to the `a`/`c`, `b`/`d` or the `tx`/`ty` column of the current
		matrix
		@param	column	The column to copy into (0, 1 or 2)
		@param	vector4	The `Vector4` instance to copy from
	**/
	public function copyColumnFrom(column:Int, vector4:Vector4):Void
	{
		if (column > 2)
		{
			throw "Column " + column + " out of bounds (2)";
		}
		else if (column == 0)
		{
			a = vector4.x;
			b = vector4.y;
		}
		else if (column == 1)
		{
			c = vector4.x;
			d = vector4.y;
		}
		else
		{
			tx = vector4.x;
			ty = vector4.y;
		}
	}

	/**
		Copies a column of the current matrix into a `Vector4`
		instance. The `w` value will not be modified.
		@param	column	The column to copy from (0, 1 or 2)
		@param	vector4	The `Vector4` instance to copy to
	**/
	public function copyColumnTo(column:Int, vector4:Vector4):Void
	{
		if (column > 2)
		{
			throw "Column " + column + " out of bounds (2)";
		}
		else if (column == 0)
		{
			vector4.x = a;
			vector4.y = b;
			vector4.z = 0;
		}
		else if (column == 1)
		{
			vector4.x = c;
			vector4.y = d;
			vector4.z = 0;
		}
		else
		{
			vector4.x = tx;
			vector4.y = ty;
			vector4.z = 1;
		}
	}

	/**
		Copies the values of a `Vector4` instance into a row
		of the current matrix
		@param	row	The row to copy into (0 or 1)
		@param	vector4	The `Vector4` instance to copy from
	**/
	public function copyRowFrom(row:Int, vector4:Vector4):Void
	{
		if (row > 2)
		{
			throw "Row " + row + " out of bounds (2)";
		}
		else if (row == 0)
		{
			a = vector4.x;
			c = vector4.y;
			tx = vector4.z;
		}
		else if (row == 1)
		{
			b = vector4.x;
			d = vector4.y;
			ty = vector4.z;
		}
	}

	/**
		Copies a row of the current matrix into a `Vector4`
		instance. The `w` value will not be modified.
		@param	row	The row to copy into (0, 1 or 2)
		@param	vector4	The `Vector4` instance to copy from
	**/
	public function copyRowTo(row:Int, vector4:Vector4):Void
	{
		if (row > 2)
		{
			throw "Row " + row + " out of bounds (2)";
		}
		else if (row == 0)
		{
			vector4.x = a;
			vector4.y = c;
			vector4.z = tx;
		}
		else if (row == 1)
		{
			vector4.x = b;
			vector4.y = d;
			vector4.z = ty;
		}
		else
		{
			vector4.setTo(0, 0, 1);
		}
	}

	@:dox(hide) public inline function toString():String
	{
		return 'matrix($a, $b, $c, $d, $tx, $ty)';
	}

	/**
		Transforms a `Rectangle` instance by the current matrix
		and returns `Rectangle` with the bounds of the transformed
		rectangle.
		@param	transform	A `Matrix3` instance to transform by
		@param	result	(Optional) A `Rectangle` instance to use for the result
		@return	A `Rectangle` represented the transformed bounds
	**/
	public function transformRect(rect:Rectangle, result:Rectangle = null):Rectangle
	{
		if (result == null) result = new Rectangle();

		var tx0 = a * rect.x + c * rect.y;
		var tx1 = tx0;
		var ty0 = b * rect.x + d * rect.y;
		var ty1 = ty0;

		var tx = a * (rect.x + rect.width) + c * rect.y;
		var ty = b * (rect.x + rect.width) + d * rect.y;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = a * (rect.x + rect.width) + c * (rect.y + rect.height);
		ty = b * (rect.x + rect.width) + d * (rect.y + rect.height);

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = a * rect.x + c * (rect.y + rect.height);
		ty = b * rect.x + d * (rect.y + rect.height);

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		result.setTo(tx0 + this.tx, ty0 + this.ty, tx1 - tx0, ty1 - ty0);
		return result;
	}

	/** The nine entries, column by column: `a, b, 0, c, d, 0, tx, ty, 1`. **/
	public function get(index:Int):Float
	{
		return switch (index)
		{
			case 0: a;
			case 1: b;
			case 3: c;
			case 4: d;
			case 6: tx;
			case 7: ty;
			case 8: 1.0;
			default: 0.0;
		}
	}

	public function set(index:Int, value:Float):Float
	{
		switch (index)
		{
			case 0: a = value;
			case 1: b = value;
			case 3: c = value;
			case 4: d = value;
			case 6: tx = value;
			case 7: ty = value;
			default:
		}
		return value;
	}
}
