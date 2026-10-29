package puffpuff.canvas;

import haxe.io.Bytes;

/**
 * Triangle list packed straight into GPU vertex layout (no intermediate `Array<Float>`):
 * 8 × f32 = 32 bytes per vertex — `x, y, coverage, paint, d0, d1, d2, d3`.
 *
 * `coverage` is 1 inside and falls to 0 across the outer AA fringe. `d0..d3` are signed distances
 * (in target pixels) inside up to four nearby straight edges; being affine they interpolate exactly,
 * so the fragment covers a pixel by how far inside it is. `FAR` = no edge.
 * `paint` is the index of the paint record the next vertices use.
 */
class Mesh {
	public static inline var STRIDE = 8;
	public static inline var BYTES = 32;
	public static inline var FAR = 1e6;

	public var bytes(default, null):Bytes;

	/** Bytes in use. **/
	public var length(default, null):Int = 0;

	public var paint:Float = 0;

	public function new(initialVertices = 1024) {
		bytes = Bytes.alloc(initialVertices * BYTES);
	}

	public inline function vertexCount():Int
		return length >> 5;

	public inline function clear():Void
		length = 0;

	/** Drops storage; `clear` keeps it for reuse. **/
	public function release():Void {
		bytes = Bytes.alloc(BYTES * 64);
		length = 0;
	}

	inline function reserve(extra:Int):Void {
		if (length + extra > bytes.length)
			grow(length + extra);
	}

	function grow(need:Int):Void {
		var size = bytes.length;
		while (size < need)
			size <<= 1;
		var next = Bytes.alloc(size);
		next.blit(0, bytes, 0, length);
		bytes = next;
	}

	public inline function vertex(x:Float, y:Float, c:Float, d0:Float = FAR, d1:Float = FAR, d2:Float = FAR, d3:Float = FAR):Void {
		reserve(BYTES);
		var b = bytes, o = length;
		b.setFloat(o, x);
		b.setFloat(o + 4, y);
		b.setFloat(o + 8, c);
		b.setFloat(o + 12, paint);
		b.setFloat(o + 16, d0);
		b.setFloat(o + 20, d1);
		b.setFloat(o + 24, d2);
		b.setFloat(o + 28, d3);
		length = o + BYTES;
	}

	public inline function triangle(ax:Float, ay:Float, ac:Float, bx:Float, by:Float, bc:Float, cx:Float, cy:Float, cc:Float):Void {
		vertex(ax, ay, ac);
		vertex(bx, by, bc);
		vertex(cx, cy, cc);
	}

	/** Quad `a b c d` (in winding order) as two triangles. **/
	public inline function quad(ax:Float, ay:Float, ac:Float, bx:Float, by:Float, bc:Float, cx:Float, cy:Float, cc:Float, dx:Float, dy:Float,
			dc:Float):Void {
		triangle(ax, ay, ac, bx, by, bc, cx, cy, cc);
		triangle(ax, ay, ac, cx, cy, cc, dx, dy, dc);
	}

	/** Copy of vertices `[from, to)`, for the translation cache. **/
	public function copyRange(from:Int, to:Int):Bytes {
		var out = Bytes.alloc((to - from) * BYTES);
		out.blit(0, bytes, from * BYTES, out.length);
		return out;
	}

	/** Appends cached vertices moved by `(dx, dy)`, restamped with the current `paint`. Distances are translation-invariant. **/
	public function appendTranslated(src:Bytes, dx:Float, dy:Float):Void {
		reserve(src.length);
		var b = bytes, o = length;
		b.blit(o, src, 0, src.length);
		var end = o + src.length;
		var p = paint;
		while (o < end) {
			b.setFloat(o, b.getFloat(o) + dx);
			b.setFloat(o + 4, b.getFloat(o + 4) + dy);
			b.setFloat(o + 12, p);
			o += BYTES;
		}
		length = end;
	}

	public inline function getX(v:Int):Float
		return bytes.getFloat(v * BYTES);

	public inline function getY(v:Int):Float
		return bytes.getFloat(v * BYTES + 4);
}

