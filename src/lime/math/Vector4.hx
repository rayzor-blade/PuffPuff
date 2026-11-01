// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;

class Vector4 {
	public var x:Float;
	public var y:Float;
	public var z:Float;
	public var w:Float;

	public function new(x:Float = 0.0, y:Float = 0.0, z:Float = 0.0, w:Float = 0.0) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}

	public inline function add(a:Vector4, result:Vector4 = null):Vector4 {
		if (result == null) result = new Vector4();
		result.setTo(x + a.x, y + a.y, z + a.z, w + a.w);
		return result;
	}

	public inline function subtract(a:Vector4, result:Vector4 = null):Vector4 {
		if (result == null) result = new Vector4();
		result.setTo(x - a.x, y - a.y, z - a.z, w - a.w);
		return result;
	}

	public inline function dotProduct(a:Vector4):Float {
		return x * a.x + y * a.y + z * a.z;
	}

	public inline function clone():Vector4 {
		return new Vector4(x, y, z, w);
	}

	public inline function copyFrom(sourceVector4:Vector4):Void {
		x = sourceVector4.x;
		y = sourceVector4.y;
		z = sourceVector4.z;
		w = sourceVector4.w;
	}

	public inline function setTo(xa:Float, ya:Float, za:Float, wa:Float = 0.0):Void {
		x = xa;
		y = ya;
		z = za;
		w = wa;
	}

	public var length(get, never):Float;
	private inline function get_length():Float {
		return Math.sqrt(lengthSquared);
	}

	public var lengthSquared(get, never):Float;
	private inline function get_lengthSquared():Float {
		return x * x + y * y + z * z;
	}

	/**
		A constant representing the x axis (1, 0, 0)
	**/
	public static var X_AXIS(get, never):Vector4;

	/**
		A constant representing the y axis (0, 1, 0)
	**/
	public static var Y_AXIS(get, never):Vector4;

	/**
		A constant representing the z axis (0, 0, 1)
	**/
	public static var Z_AXIS(get, never):Vector4;

	/**
		Performs vector multiplication between this vector and another `Vector4` instance
		@param	a	A `Vector4` instance to multiply by
		@param	result	(Optional) A `Vector4` to use for the result
		@return	A `Vector4` instance with the result
	**/
	public inline function crossProduct(a:Vector4, result:Vector4 = null):Vector4
	{
		if (result == null) result = new Vector4();
		result.setTo(y * a.z - z * a.y, z * a.x - x * a.z, x * a.y - y * a.x);
		result.w = 1;
		return result;
	}

	/**
		Decrements the x, y and z component values by those in another `Vector4` instance
		@param	a	A `Vector4` instance to decrement the current vector by
	**/
	public inline function decrementBy(a:Vector4):Void
	{
		x -= a.x;
		y -= a.y;
		z -= a.z;
	}

	/**
		Calculates the distance between two vectors
		@param	pt1	A `Vector4` instance
		@param	pt2	A second `Vector4` instance
		@return	The distance between each vector
	**/
	public inline static function distance(pt1:Vector4, pt2:Vector4):Float
	{
		var x = pt2.x - pt1.x;
		var y = pt2.y - pt1.y;
		var z = pt2.z - pt1.z;

		return Math.sqrt(x * x + y * y + z * z);
	}

	/**
		Whether two `Vector4` instances have equal component values.

		Comparing the w component value is optional.
		@param	toCompare	A `Vector4` instance to compare against
		@param	allFour	(Optional) Whether to compare against the w component (default is false)
		@return	Whether both instances have equal values
	**/
	public inline function equals(toCompare:Vector4, ?allFour:Bool = false):Bool
	{
		return x == toCompare.x && y == toCompare.y && z == toCompare.z && (!allFour || w == toCompare.w);
	}

	/**
		Increments the x, y and z component values by those in a second `Vector4` instance
		@param	a	A `Vector4` instance to increment the current vector by
	**/
	public inline function incrementBy(a:Vector4):Void
	{
		x += a.x;
		y += a.y;
		z += a.z;
	}

	/**
		Whether two `Vector4` instances have nearly equal component values.
		Comparison is performed within a given tolerance value.
		@param	toCompare	A `Vector4` instance to compare against
		@param	tolerance	A floating point value determining how near the values must be to be considered near equal
		@param	allFour	(Optional) Whether to compare against the w component (default is false)
		@return	Whether both instances have equal values, within the given tolerance
	**/
	public inline function nearEquals(toCompare:Vector4, tolerance:Float, ?allFour:Bool = false):Bool
	{
		return Math.abs(x - toCompare.x) < tolerance
			&& Math.abs(y - toCompare.y) < tolerance
			&& Math.abs(z - toCompare.z) < tolerance
			&& (!allFour || Math.abs(w - toCompare.w) < tolerance);
	}

	/**
		Negates the x, y and z values of the current vector
		(multiplying each value by -1)
	**/
	public inline function negate():Void
	{
		x *= -1;
		y *= -1;
		z *= -1;
	}

	/**
		Divides the x, y and z component values by the
		length of the vector
	**/
	public inline function normalize():Float
	{
		var l = length;

		if (l != 0)
		{
			x /= l;
			y /= l;
			z /= l;
		}

		return l;
	}

	/**
		Divides the x, y and z component values by the
		w component value
	**/
	public inline function project():Void
	{
		x /= w;
		y /= w;
		z /= w;
	}

	/**
		Scales the x, y and z component values by a scale value
		@param	s	The amount of scale to apply
	**/
	public inline function scaleBy(s:Float):Void
	{
		x *= s;
		y *= s;
		z *= s;
	}

	@:dox(hide) public inline function toString():String
	{
		return "Vector4(" + x + ", " + y + ", " + z + ")";
	}

	private inline static function get_X_AXIS():Vector4
	{
		return new Vector4(1, 0, 0);
	}

	private inline static function get_Y_AXIS():Vector4
	{
		return new Vector4(0, 1, 0);
	}

	private inline static function get_Z_AXIS():Vector4
	{
		return new Vector4(0, 0, 1);
	}

	/**
		Calculates the angle between two `Vector4` coordinates
		@param	a	A `Vector4` instance
		@param	b	A second `Vector4` instance
		@return	The calculated angle
	**/
	public static inline function angleBetween(a:Vector4, b:Vector4):Float
	{
		var a0 = a.clone();
		a0.normalize();
		var b0 = b.clone();
		b0.normalize();

		return Math.acos(a0.dotProduct(b0));
	}

	/**
		Calculates the squared distance between two vectors,
		(avoids the use of `Math.sqrt` for faster performance)
		@param	pt1	A `Vector4` instance
		@param	pt2	A second `Vector4` instance
		@return	The square of the distance between each vector
	**/
	public inline static function distanceSquared(pt1:Vector4, pt2:Vector4):Float
	{
		var x = pt2.x - pt1.x;
		var y = pt2.y - pt1.y;
		var z = pt2.z - pt1.z;

		return x * x + y * y + z * z;
	}
}
