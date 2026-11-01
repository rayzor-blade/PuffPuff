package puffpuff.canvas;

import haxe.io.Bytes;

typedef GradientStop = {offset:Float, rgb:Int, alpha:Float};

enum abstract PaintKind(Int) to Int {
	var Solid = 0;
	var Linear = 1;
	var Radial = 2;
}

/**
 * Fill color source. Encoded as `RECORD_FLOATS` (8 × vec4) for `VectorPathShader`:
 *   0: kind, stopCount, opacity, focal
 *   1: `a, b, c, d` of the map from target pixels to gradient space
 *   2: stop offsets (≤ 4)
 *   3..6: stop colors, straight RGBA (solid uses 3)
 *   7: `e, f` of that map, spread (0 pad, 1 reflect, 2 repeat), 0
 * Stops past the fourth follow in further records, four to a record: their offsets, then their colors (`records`).
 * Gradient space is where the gradient's parameter is read off directly: linear `t = x`, radial
 * `t = length`. The map is built from path units through the draw transform at encode time, so a
 * gradient can be stretched, rotated and skewed with its shape.
 */
class Paint {
	public static inline var RECORD_VEC4 = 8;
	public static inline var RECORD_BYTES = RECORD_VEC4 * 16;

	/** Flash allows 15; more are dropped. **/
	public static inline var MAX_STOPS = 16;

	/** A focal point on the rim has no gradient to give; stay just inside. **/
	static inline var MAX_FOCAL = 0.99;

	public var kind:PaintKind;
	public var rgb:Int;
	public var alpha:Float;
	public var stops:Array<GradientStop>;

	/** Path units → gradient space, as an `Affine`'s `a, b, c, d, e, f`. **/
	public var ma:Float = 1;
	public var mb:Float = 0;
	public var mc:Float = 0;
	public var md:Float = 1;
	public var me:Float = 0;
	public var mf:Float = 0;

	/** 0 pad, 1 reflect, 2 repeat. **/
	public var spread:Int = 0;

	/** Radial only: where the gradient starts, along gradient space's x as a fraction of the radius, in (-1, 1). **/
	public var focal:Float = 0;

	function new(kind:PaintKind, rgb:Int, alpha:Float, ?stops:Array<GradientStop>) {
		this.kind = kind;
		this.rgb = rgb;
		this.alpha = alpha;
		this.stops = stops == null ? [] : stops;
	}

	public static function solid(rgb:Int, alpha = 1.0):Paint
		return new Paint(Solid, rgb, alpha);

	/** From `(x0, y0)` (offset 0) to `(x1, y1)` (offset 1), in path units. **/
	public static function linear(x0:Float, y0:Float, x1:Float, y1:Float, stops:Array<GradientStop>, spread = 0):Paint {
		var p = new Paint(Linear, 0, 1, sorted(stops));
		var dx = x1 - x0, dy = y1 - y0;
		var l = Math.max(dx * dx + dy * dy, 1e-12);
		p.ma = dx / l;
		p.mc = dy / l;
		p.me = -(dx * x0 + dy * y0) / l;
		p.spread = spread;
		return p;
	}

	/** Offset 1 is at distance `r` from `(cx, cy)`, in path units. **/
	public static function radial(cx:Float, cy:Float, r:Float, stops:Array<GradientStop>, spread = 0):Paint {
		var p = new Paint(Radial, 0, 1, sorted(stops));
		var k = 1 / Math.max(r, 1e-9);
		p.ma = k;
		p.md = k;
		p.me = -cx * k;
		p.mf = -cy * k;
		p.spread = spread;
		return p;
	}

	/**
		A gradient placed by `box`, which maps gradient space onto path units. Linear runs from `(0, 0)` to `(1, 0)`, radial
		from the center `(0, 0)` out to the unit circle. Any affine map works, so ellipses and rotations are covered.
	**/
	public static function boxed(kind:PaintKind, box:Affine, stops:Array<GradientStop>, spread = 0, focal = 0.0):Paint {
		var p = new Paint(kind, 0, 1, sorted(stops));
		var inverse = box.inverse();
		if (inverse != null) {
			p.ma = inverse.a;
			p.mb = inverse.b;
			p.mc = inverse.c;
			p.md = inverse.d;
			p.me = inverse.e;
			p.mf = inverse.f;
		}
		p.spread = spread;
		p.focal = Math.max(-MAX_FOCAL, Math.min(MAX_FOCAL, focal));
		return p;
	}

	static function sorted(stops:Array<GradientStop>):Array<GradientStop> {
		var s = stops.copy();
		s.sort((a, b) -> a.offset < b.offset ? -1 : a.offset > b.offset ? 1 : 0);
		return s;
	}

	/** Records `encode` writes: one, and one more for each four stops past the fourth. **/
	public function records():Int {
		var n = kind == Solid ? 0 : Std.int(Math.min(MAX_STOPS, stops.length));
		return n <= 4 ? 1 : 1 + (n - 1 >> 2);
	}

	/** Writes this paint's record(s) at byte `at` of `out` through transform `m`. **/
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
		var count = Std.int(Math.min(MAX_STOPS, stops.length));
		var n = Std.int(Math.min(4, count));
		four(0, kind, count, opacity, kind == Radial ? focal : 0);
		// Pixels to path units is the inverse of `m`. Gradient space follows from that.
		var det = m.a * m.d - m.b * m.c;
		if (Math.abs(det) < 1e-12) {
			four(0, 0, 1, 0, 0);
			for (k in 1...8)
				four(k * 16, 0, 0, 0, 0);
			return;
		}
		var ia = m.d / det, ib = -m.b / det, ic = -m.c / det, id = m.a / det;
		var ie = -(ia * m.e + ic * m.f), iff = -(ib * m.e + id * m.f);
		four(16, ma * ia + mc * ib, mb * ia + md * ib, ma * ic + mc * id, mb * ic + md * id);
		four(32, stops[0].offset, n > 1 ? stops[1].offset : 1, n > 2 ? stops[2].offset : 1, n > 3 ? stops[3].offset : 1);
		for (i in 0...4) {
			var s = stops[i < n ? i : n - 1];
			rgba(48 + i * 16, s.rgb, s.alpha);
		}
		four(112, ma * ie + mc * iff + me, mb * ie + md * iff + mf, spread, 0);
		for (j in 1...records()) {
			var o = j * RECORD_BYTES;
			var first = j * 4;
			inline function stop(i:Int):GradientStop
				return stops[first + i < count ? first + i : count - 1];
			out.setFloat(at + o, stop(0).offset);
			out.setFloat(at + o + 4, stop(1).offset);
			out.setFloat(at + o + 8, stop(2).offset);
			out.setFloat(at + o + 12, stop(3).offset);
			for (i in 0...4)
				rgba(o + 16 + i * 16, stop(i).rgb, stop(i).alpha);
			for (k in 5...8)
				four(o + k * 16, 0, 0, 0, 0);
		}
	}
}
