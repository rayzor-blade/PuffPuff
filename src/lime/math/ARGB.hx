// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;

abstract ARGB(Int) from Int to Int from UInt to UInt {
	public var a(get, set):Int;
	public var r(get, set):Int;
	public var g(get, set):Int;
	public var b(get, set):Int;

	public inline function new(argb:Int = 0) {
		this = argb;
	}

	public static inline function create(a:Int, r:Int, g:Int, b:Int):ARGB {
		var argb = new ARGB();
		argb.set(a, r, g, b);
		return argb;
	}

	public inline function multiplyAlpha():Void {
		if (a == 0) {
			if (this != 0) this = 0;
		} else if (a != 0xFF) {
			set(a, Std.int((r * a + 127) / 255), Std.int((g * a + 127) / 255), Std.int((b * a + 127) / 255));
		}
	}

	public inline function unmultiplyAlpha():Void {
		if (a != 0 && a != 0xFF) {
			var inv = 255.0 / a;
			set(a, Std.int(Math.min(255, Math.round(r * inv))), Std.int(Math.min(255, Math.round(g * inv))), Std.int(Math.min(255, Math.round(b * inv))));
		}
	}

	public inline function set(a:Int, r:Int, g:Int, b:Int):Void {
		this = ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
	}

	private inline function get_a():Int return (this >> 24) & 0xFF;
	private inline function set_a(v:Int):Int { set(v, r, g, b); return v; }
	private inline function get_r():Int return (this >> 16) & 0xFF;
	private inline function set_r(v:Int):Int { set(a, v, g, b); return v; }
	private inline function get_g():Int return (this >> 8) & 0xFF;
	private inline function set_g(v:Int):Int { set(a, r, v, b); return v; }
	private inline function get_b():Int return this & 0xFF;
	private inline function set_b(v:Int):Int { set(a, r, g, v); return v; }
}
