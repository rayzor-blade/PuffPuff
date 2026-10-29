// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;

abstract BGRA(Int) from Int to Int from UInt to UInt {
	public var b(get, set):Int;
	public var g(get, set):Int;
	public var r(get, set):Int;
	public var a(get, set):Int;

	public inline function new(bgra:Int = 0) {
		this = bgra;
	}

	public static inline function create(b:Int, g:Int, r:Int, a:Int):BGRA {
		var bgra = new BGRA();
		bgra.set(b, g, r, a);
		return bgra;
	}

	public inline function multiplyAlpha():Void {
		if (a == 0) {
			if (this != 0) this = 0;
		} else if (a != 0xFF) {
			set(Std.int((b * a + 127) / 255), Std.int((g * a + 127) / 255), Std.int((r * a + 127) / 255), a);
		}
	}

	public inline function unmultiplyAlpha():Void {
		if (a != 0 && a != 0xFF) {
			var inv = 255.0 / a;
			set(Std.int(Math.min(255, Math.round(b * inv))), Std.int(Math.min(255, Math.round(g * inv))), Std.int(Math.min(255, Math.round(r * inv))), a);
		}
	}

	public inline function set(b:Int, g:Int, r:Int, a:Int):Void {
		this = ((b & 0xFF) << 24) | ((g & 0xFF) << 16) | ((r & 0xFF) << 8) | (a & 0xFF);
	}

	@:from private static inline function __fromARGB(argb:ARGB):BGRA {
		return BGRA.create(argb.b, argb.g, argb.r, argb.a);
	}

	@:from private static inline function __fromRGBA(rgba:RGBA):BGRA {
		return BGRA.create(rgba.b, rgba.g, rgba.r, rgba.a);
	}

	@:to private inline function __toARGB():ARGB {
		return ARGB.create(a, r, g, b);
	}

	@:to private inline function __toRGBA():RGBA {
		return RGBA.create(r, g, b, a);
	}

	private inline function get_b():Int return (this >> 24) & 0xFF;
	private inline function set_b(v:Int):Int { set(v, g, r, a); return v; }
	private inline function get_g():Int return (this >> 16) & 0xFF;
	private inline function set_g(v:Int):Int { set(b, v, r, a); return v; }
	private inline function get_r():Int return (this >> 8) & 0xFF;
	private inline function set_r(v:Int):Int { set(b, g, v, a); return v; }
	private inline function get_a():Int return this & 0xFF;
	private inline function set_a(v:Int):Int { set(b, g, r, v); return v; }
}
