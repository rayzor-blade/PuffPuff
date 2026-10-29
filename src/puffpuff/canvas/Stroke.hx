package puffpuff.canvas;

enum abstract LineCap(Int) {
	var Butt = 0;
	var Round = 1;
	var Square = 2;
}

enum abstract LineJoin(Int) {
	var Miter = 0;
	var Round = 1;
	var Bevel = 2;
}

/** Outline style. `dash` alternates dash/gap lengths in path units; empty = solid. **/
class Stroke {
	public var width:Float;
	public var cap:LineCap;
	public var join:LineJoin;

	/** Max miter length in widths before falling back to bevel. **/
	public var miterLimit:Float;

	public var dash:Array<Float>;
	public var dashOffset:Float;

	public function new(width = 1.0, ?cap:LineCap, ?join:LineJoin, miterLimit = 4.0, ?dash:Array<Float>, dashOffset = 0.0) {
		this.width = width;
		this.cap = cap == null ? Butt : cap;
		this.join = join == null ? Miter : join;
		this.miterLimit = miterLimit;
		this.dash = dash == null ? [] : dash;
		this.dashOffset = dashOffset;
	}

	public function same(other:Null<Stroke>):Bool {
		if (other == this)
			return true;
		if (other == null || width != other.width || cap != other.cap || join != other.join || miterLimit != other.miterLimit
			|| dashOffset != other.dashOffset || dash.length != other.dash.length)
			return false;
		for (i in 0...dash.length)
			if (dash[i] != other.dash[i])
				return false;
		return true;
	}
}

