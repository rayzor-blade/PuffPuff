// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;

class Vector2 {
	public var x:Float;
	public var y:Float;

	public var length(get, never):Float;
	public var lengthSquared(get, never):Float;

	public function new(x:Float = 0.0, y:Float = 0.0) {
		this.x = x;
		this.y = y;
	}

	public inline function add(v:Vector2, result:Vector2 = null):Vector2 {
		if (result == null) result = new Vector2();
		result.setTo(x + v.x, y + v.y);
		return result;
	}

	public inline function subtract(v:Vector2, result:Vector2 = null):Vector2 {
		if (result == null) result = new Vector2();
		result.setTo(x - v.x, y - v.y);
		return result;
	}

	public inline function clone():Vector2 {
		return new Vector2(x, y);
	}

	public static inline function distance(pt1:Vector2, pt2:Vector2):Float {
		var dx = pt1.x - pt2.x;
		var dy = pt1.y - pt2.y;
		return Math.sqrt(dx * dx + dy * dy);
	}

	public inline function equals(toCompare:Vector2):Bool {
		return toCompare != null && toCompare.x == x && toCompare.y == y;
	}

	public static inline function interpolate(pt1:Vector2, pt2:Vector2, f:Float, result:Vector2 = null):Vector2 {
		if (result == null) result = new Vector2();
		result.setTo(pt2.x + f * (pt1.x - pt2.x), pt2.y + f * (pt1.y - pt2.y));
		return result;
	}

	public inline function normalize(thickness:Float = 1.0):Void {
		if (x == 0 && y == 0) return;
		var norm = thickness / Math.sqrt(x * x + y * y);
		x *= norm;
		y *= norm;
	}

	public inline function offset(dx:Float, dy:Float):Void {
		x += dx;
		y += dy;
	}

	public static inline function polar(len:Float, angle:Float, result:Vector2 = null):Vector2 {
		if (result == null) result = new Vector2();
		result.setTo(len * Math.cos(angle), len * Math.sin(angle));
		return result;
	}

	public inline function setTo(xa:Float, ya:Float):Void {
		x = xa;
		y = ya;
	}

	private inline function get_length():Float {
		return Math.sqrt(x * x + y * y);
	}

	private inline function get_lengthSquared():Float {
		return x * x + y * y;
	}
}
