// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;

abstract RGBA(Int) from Int to Int from UInt to UInt {
	public var r(get, set):Int;
	public var g(get, set):Int;
	public var b(get, set):Int;
	public var a(get, set):Int;

	public inline function new(rgba:Int = 0) {
		this = rgba;
	}

	public static inline function create(r:Int, g:Int, b:Int, a:Int):RGBA {
		var rgba = new RGBA();
		rgba.set(r, g, b, a);
		return rgba;
	}

	public inline function multiplyAlpha():Void {
		if (a == 0) {
			if (this != 0) this = 0;
		} else if (a != 0xFF) {
			set(Std.int((r * a + 127) / 255), Std.int((g * a + 127) / 255), Std.int((b * a + 127) / 255), a);
		}
	}

	public inline function unmultiplyAlpha():Void {
		if (a != 0 && a != 0xFF) {
			var inv = 255.0 / a;
			set(Std.int(Math.min(255, Math.round(r * inv))), Std.int(Math.min(255, Math.round(g * inv))), Std.int(Math.min(255, Math.round(b * inv))), a);
		}
	}

	public inline function set(r:Int, g:Int, b:Int, a:Int):Void {
		this = ((r & 0xFF) << 24) | ((g & 0xFF) << 16) | ((b & 0xFF) << 8) | (a & 0xFF);
	}

	@:from private static inline function __fromARGB(argb:ARGB):RGBA {
		return RGBA.create(argb.r, argb.g, argb.b, argb.a);
	}

	@:to private inline function __toARGB():ARGB {
		return ARGB.create(a, r, g, b);
	}

	private inline function get_r():Int return (this >> 24) & 0xFF;
	private inline function set_r(v:Int):Int { set(v, g, b, a); return v; }
	private inline function get_g():Int return (this >> 16) & 0xFF;
	private inline function set_g(v:Int):Int { set(r, v, b, a); return v; }
	private inline function get_b():Int return (this >> 8) & 0xFF;
	private inline function set_b(v:Int):Int { set(r, g, v, a); return v; }
	private inline function get_a():Int return this & 0xFF;
	private inline function set_a(v:Int):Int { set(r, g, b, v); return v; }
}
