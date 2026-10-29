package puffpuff.canvas;

import haxe.io.Bytes;

typedef GradientStop = {offset:Float, rgb:Int, alpha:Float};

enum abstract PaintKind(Int) to Int {
	var Solid = 0;
	var Linear = 1;
	var Radial = 2;
}

/**
 * Fill colour source. Encoded as `RECORD_FLOATS` (8 × vec4) for `VectorPathShader`:
 *   0: kind, stopCount, opacity, 0
 *   1: geometry in target pixels — linear `x0, y0, x1, y1`; radial `cx, cy, r, 0`
 *   2: stop offsets (≤ 4)
 *   3..6: stop colours, straight RGBA (solid uses 3)
 *   7: reserved
 * Gradient geometry is in path units and goes through the draw transform at encode time.
 */
class Paint {
	public static inline var RECORD_VEC4 = 8;
	public static inline var RECORD_BYTES = RECORD_VEC4 * 16;

	public var kind:PaintKind;
	public var rgb:Int;
	public var alpha:Float;
	public var x0:Float = 0;
	public var y0:Float = 0;
	public var x1:Float = 0;
	public var y1:Float = 0;
	public var radius:Float = 0;
	public var stops:Array<GradientStop>;

	function new(kind:PaintKind, rgb:Int, alpha:Float, ?stops:Array<GradientStop>) {
		this.kind = kind;
		this.rgb = rgb;
		this.alpha = alpha;
		this.stops = stops == null ? [] : stops;
	}

	public static function solid(rgb:Int, alpha = 1.0):Paint
		return new Paint(Solid, rgb, alpha);

	public static function linear(x0:Float, y0:Float, x1:Float, y1:Float, stops:Array<GradientStop>):Paint {
		var p = new Paint(Linear, 0, 1, sorted(stops));
		p.x0 = x0;
		p.y0 = y0;
		p.x1 = x1;
		p.y1 = y1;
		return p;
	}

	public static function radial(cx:Float, cy:Float, r:Float, stops:Array<GradientStop>):Paint {
		var p = new Paint(Radial, 0, 1, sorted(stops));
		p.x0 = cx;
		p.y0 = cy;
		p.radius = r;
		return p;
	}

	static function sorted(stops:Array<GradientStop>):Array<GradientStop> {
		var s = stops.copy();
		s.sort((a, b) -> a.offset < b.offset ? -1 : a.offset > b.offset ? 1 : 0);
		return s;
	}

	/** Writes this paint's record at byte `at` of `out` through transform `m`. **/
	public function encode(out:Bytes, at:Int, m:Affine, opacity:Float):Void {
		inline function four(o:Int, a:Float, b:Float, c:Float, d:Float) {
			out.setFloat(at + o, a);
			out.setFloat(at + o + 4, b);
			out.setFloat(at + o + 8, c);
			out.setFloat(at + o + 12, d);
		}
		inline function rgba(o:Int, rgb:Int, a:Float)
			four(o, (rgb >> 16 & 0xFF) / 255, (rgb >> 8 & 0xFF) / 255, (rgb & 0xFF) / 255, a);
		if (kind == Solid || stops.length == 0) {
			four(0, 0, 1, opacity, 0);
			four(16, 0, 0, 0, 0);
			four(32, 0, 0, 0, 0);
			rgba(48, rgb, alpha);
			for (k in 4...8)
				four(k * 16, 0, 0, 0, 0);
			return;
		}
		var n = Std.int(Math.min(4, stops.length));
		four(0, kind, n, opacity, 0);
		if (kind == Radial)
			four(16, m.x(x0, y0), m.y(x0, y0), radius * m.scale(), 0);
		else
			four(16, m.x(x0, y0), m.y(x0, y0), m.x(x1, y1), m.y(x1, y1));
		four(32, stops[0].offset, n > 1 ? stops[1].offset : 1, n > 2 ? stops[2].offset : 1, n > 3 ? stops[3].offset : 1);
		for (i in 0...4) {
			var s = stops[i < n ? i : n - 1];
			rgba(48 + i * 16, s.rgb, s.alpha);
		}
		four(112, 0, 0, 0, 0);
	}
}

