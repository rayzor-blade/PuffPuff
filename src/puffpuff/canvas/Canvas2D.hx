package puffpuff.canvas;

import gpu.BufferUsage;
import gpu.GpuBuffer;
import gpu.GpuBufferDescriptor;
import haxe.io.Bytes;
import lime.math.Matrix4;
import puffpuff.canvas.Flatten.Contour;
import puffpuff.canvas.Path.FillRule;
import puffpuff.gpu.WgpuContext3D;

/**
 * Immediate-mode GPU vector canvas: `begin`, then `fill`/`stroke`, then `flush` to draw everything
 * in one call with `VectorPathShader`, in submission order, antialiased analytically (no MSAA).
 *
 * Retained under the hood: each path is looked up by content (`Path.signature` + `Path.same`).
 * A path redrawn with the same linear transform, stroke and rule reuses last frame's triangles,
 * shifted by the change in translation — no flattening, no sweep. Its triangles are copied out the
 * second time it is seen, so paths drawn only once never pay for the copy.
 *
 * Invariant: at most one `flush` per canvas per submitted encoder — vertex/paint buffers are
 * rewritten through the queue, which lands before any pass of that submission runs.
 */
class Canvas2D {
	/** Max chord deviation of flattened curves, in target pixels. **/
	public static inline var TOLERANCE = 0.25;

	/** Applied after each draw's own transform; maps path units to target pixels × `1/pixelRatio`. **/
	public var transform:Affine = Affine.IDENTITY;

	/** Target pixels per canvas unit: the AA fringe is one target pixel wide. **/
	public var pixelRatio:Float = 1.0;

	/** When set, each draw's bounds go into `hits` for `hitTest`. **/
	public var trackHits:Bool = false;

	public final hits = new SpatialIndex<Int>();

	final ctx:WgpuContext3D;
	final mesh = new Mesh();
	var paints:Bytes = Bytes.alloc(Paint.RECORD_BYTES * 64);
	var paintCount = 0;
	var builds = 0;

	final shapes = new haxe.ds.IntMap<Array<Shape>>();
	final emptied:Array<Int> = [];

	var vertexBuffer:Null<GpuBuffer> = null;
	var vertexCapacity = 0;
	var paintBuffer:Null<GpuBuffer> = null;
	var paintCapacity = 0;

	public var drawCount(get, never):Int;
	public var vertexCount(get, never):Int;

	/** Draws this build that reused cached triangles. **/
	public var reused(default, null):Int = 0;

	inline function get_drawCount():Int
		return paintCount;

	inline function get_vertexCount():Int
		return mesh.vertexCount();

	public function new(ctx:WgpuContext3D) {
		this.ctx = ctx;
	}

	public function begin():Void {
		builds++;
		mesh.clear();
		paintCount = 0;
		reused = 0;
		if (trackHits)
			hits.clear();
	}

	public function fill(path:Path, paint:Paint, rule:FillRule = NonZero, ?local:Affine, opacity = 1.0):Void
		draw(path, paint, rule, null, local, opacity);

	public function stroke(path:Path, stroke:Stroke, paint:Paint, ?local:Affine, opacity = 1.0):Void
		draw(path, paint, NonZero, stroke, local, opacity);

	public inline function fillRect(x:Float, y:Float, w:Float, h:Float, paint:Paint, ?local:Affine):Void
		fill(new Path().rect(x, y, w, h), paint, NonZero, local);

	/** Draw indices whose bounds contain `(x, y)`, topmost last. Needs `trackHits`. **/
	public inline function hitTest(x:Float, y:Float):Array<Int>
		return hits.query(x, y);

	function draw(path:Path, paint:Paint, rule:FillRule, stroke:Null<Stroke>, local:Null<Affine>, opacity:Float):Void {
		var m = local == null ? transform : transform.after(local);
		var aa = 1 / pixelRatio;
		var tolerance = TOLERANCE / pixelRatio;
		var before = mesh.vertexCount();
		mesh.paint = paintCount;
		tessellate(path, m, tolerance, aa, rule, stroke);
		var after = mesh.vertexCount();
		if (after == before)
			return;
		var at = paintCount * Paint.RECORD_BYTES;
		if (at + Paint.RECORD_BYTES > paints.length) {
			var next = Bytes.alloc(paints.length * 2);
			next.blit(0, paints, 0, at);
			paints = next;
		}
		paint.encode(paints, at, m, opacity);
		if (trackHits) {
			var x0 = Math.POSITIVE_INFINITY, y0 = Math.POSITIVE_INFINITY;
			var x1 = Math.NEGATIVE_INFINITY, y1 = Math.NEGATIVE_INFINITY;
			for (v in before...after) {
				var x = mesh.getX(v), y = mesh.getY(v);
				if (x < x0) x0 = x;
				if (x > x1) x1 = x;
				if (y < y0) y0 = y;
				if (y > y1) y1 = y;
			}
			hits.insert(paintCount, x0, y0, x1, y1);
		}
		paintCount++;
	}

	function shapeOf(path:Path):Null<Shape> {
		var bucket = shapes.get(path.signature());
		if (bucket != null)
			for (known in bucket)
				if (Path.same(known.path, path))
					return known;
		return null;
	}

	function tessellate(path:Path, m:Affine, tolerance:Float, aa:Float, rule:FillRule, stroke:Null<Stroke>):Void {
		var known = shapeOf(path);
		if (known != null && known.data != null && known.m.sameLinear(m) && known.tolerance == tolerance && known.aa == aa && known.rule == rule
			&& (stroke == null ? known.stroke == null : stroke.same(known.stroke))) {
			mesh.appendTranslated(known.data, m.e - known.m.e, m.f - known.m.f);
			known.build = builds;
			reused++;
			return;
		}
		var from = mesh.vertexCount();
		var flat:Array<Contour> = Flatten.path(path, m, tolerance);
		if (stroke != null)
			Tessellate.stroke(flat, stroke, m.scale(), aa, mesh);
		else
			Tessellate.fill(flat, rule, aa, mesh);
		if (known != null)
			shapes.get(path.signature()).remove(known);
		var sig = path.signature();
		var bucket = shapes.get(sig);
		if (bucket == null)
			shapes.set(sig, bucket = []);
		bucket.push({
			build: builds,
			path: path,
			m: m,
			tolerance: tolerance,
			aa: aa,
			rule: rule,
			stroke: stroke,
			// Seen before (any transform): worth keeping triangles for next time.
			data: known != null ? mesh.copyRange(from, mesh.vertexCount()) : null
		});
	}

	function forgetUnused():Void {
		for (sig => bucket in shapes) {
			var i = bucket.length;
			while (i-- > 0)
				if (bucket[i].build != builds)
					bucket.splice(i, 1);
			if (bucket.length == 0)
				emptied.push(sig);
		}
		for (sig in emptied)
			shapes.remove(sig);
		emptied.resize(0);
	}

	/** Uploads this build and draws it into the current target with `projection` (canvas pixels → clip). **/
	public function flush(projection:Matrix4):Void {
		forgetUnused();
		var count = mesh.vertexCount();
		if (count == 0)
			return;
		var dev = ctx.wgpu.device;
		if (vertexBuffer == null || mesh.length > vertexCapacity) {
			if (vertexBuffer != null)
				vertexBuffer.destroy();
			vertexCapacity = mesh.length + (mesh.length >> 1);
			vertexBuffer = dev.createBuffer(new GpuBufferDescriptor(vertexCapacity, BufferUsage.VERTEX | BufferUsage.COPY_DST));
		}
		var paintBytes = paintCount * Paint.RECORD_BYTES;
		if (paintBuffer == null || paintBytes > paintCapacity) {
			if (paintBuffer != null)
				paintBuffer.destroy();
			paintCapacity = paintBytes + (paintBytes >> 1);
			paintBuffer = dev.createBuffer(new GpuBufferDescriptor(paintCapacity, BufferUsage.STORAGE | BufferUsage.COPY_DST));
		}
		ctx.wgpu.queue.writeBuffer(vertexBuffer, 0, mesh.bytes, mesh.length);
		ctx.wgpu.queue.writeBuffer(paintBuffer, 0, paints, paintBytes);
		ctx.drawVectorMesh(vertexBuffer, count, paintBuffer, projection);
	}

	public function dispose():Void {
		if (vertexBuffer != null)
			vertexBuffer.destroy();
		if (paintBuffer != null)
			paintBuffer.destroy();
		vertexBuffer = paintBuffer = null;
		shapes.clear();
		mesh.release();
	}
}

private typedef Shape = {
	build:Int,
	path:Path,
	m:Affine,
	tolerance:Float,
	aa:Float,
	rule:FillRule,
	stroke:Null<Stroke>,
	data:Null<Bytes>
}

