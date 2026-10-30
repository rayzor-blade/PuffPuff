import gpu.VertexFormat;
import haxe.io.Bytes;
import lime.math.Matrix4;
import lime.utils.Float32Array;
import puffpuff.canvas.Affine;
import puffpuff.canvas.Canvas2D;
import puffpuff.canvas.Paint;
import puffpuff.canvas.Path;
import puffpuff.gpu.QuadBatcher;
import puffpuff.snapshot.Snapshot;

/**
 * Asserting snapshot of buffers rewritten several times within one frame: one `Canvas2D` flushed
 * repeatedly between sprite draws (including a flush that outgrows its buffers mid-frame), and one
 * Context3D vertex buffer re-uploaded — fully, then partially — between `drawTriangles`.
 *
 * Top row, left to right: red box under a yellow sprite under a green box, a blue grid (the
 * growing flush), and a magenta box reusing the red box's cached triangles. Bottom row: a cyan
 * quad, an orange quad, and an orange-to-purple parallelogram sharing the orange quad's lower edge.
 */
class MultiFlushScene {
	static inline var W = 400;
	static inline var H = 200;

	static final failures:Array<String> = [];

	static function ortho(w:Float, h:Float):Matrix4 {
		var m = new Matrix4();
		m.createOrtho(0, w, h, 0, -1, 1);
		return m;
	}

	static function solidTexture(c3:puffpuff.gpu.WgpuContext3D, rgb:Int) {
		var tex = c3.createTexture(4, 4);
		var bytes = Bytes.alloc(4 * 4 * 4);
		for (i in 0...16) {
			bytes.set(i * 4, (rgb >> 16) & 0xFF);
			bytes.set(i * 4 + 1, (rgb >> 8) & 0xFF);
			bytes.set(i * 4 + 2, rgb & 0xFF);
			bytes.set(i * 4 + 3, 255);
		}
		tex.uploadFromBytes(bytes);
		return tex;
	}

	static function quad(x0:Float, y0:Float, x1:Float, y1:Float, r:Float, g:Float, b:Float):Float32Array {
		return new Float32Array([
			x0, y0, r, g, b, 1.0,
			x1, y0, r, g, b, 1.0,
			x1, y1, r, g, b, 1.0,
			x0, y1, r, g, b, 1.0
		]);
	}

	static function expect(what:String, x:Int, y:Int, rgb:Int, tolerance = 24):Void {
		var px = Snapshot.pixels;
		var at = (y * W + x) * 4;
		var r = px.get(at), g = px.get(at + 1), b = px.get(at + 2);
		var er = (rgb >> 16) & 0xFF, eg = (rgb >> 8) & 0xFF, eb = rgb & 0xFF;
		if (Math.abs(r - er) > tolerance || Math.abs(g - eg) > tolerance || Math.abs(b - eb) > tolerance)
			failures.push('$what at ($x,$y): got ${StringTools.hex((r << 16) | (g << 8) | b, 6)}, want ${StringTools.hex(rgb, 6)}');
	}

	static function main():Void {
		var box = new Path().rect(0, 0, 80, 80);

		Snapshot.scene("multi-flush-scene", W, H, ctx -> {
			var c3 = ctx.wgpu.context3D;
			var proj = ortho(W, H);
			c3.beginRenderPass(0, 0, 0, 1);

			var cv = new Canvas2D(c3);
			var sprites = new QuadBatcher(c3, 4);
			var yellow = solidTexture(c3, 0xFFFF00);

			cv.begin();
			cv.fill(box, Paint.solid(0xFF0000), NonZero, Affine.translation(10, 10));
			cv.flush(proj);

			sprites.begin(yellow);
			sprites.addQuad(40, 0, 0, 40, 60, 30);
			sprites.flush(proj);

			cv.begin();
			cv.fill(new Path().rect(90, 10, 30, 80), Paint.solid(0x00FF00));
			cv.flush(proj);

			// Far more vertices and paints than the buffers were sized for, so they grow mid-frame.
			cv.begin();
			for (i in 0...400)
				cv.fill(new Path().rect(130 + (i % 20) * 4, 10 + Std.int(i / 20) * 4, 3, 3), Paint.solid(0x0000FF));
			cv.flush(proj);

			cv.begin();
			cv.fill(box, Paint.solid(0xFF00FF), NonZero, Affine.translation(220, 10));
			cv.flush(proj);

			var vb = c3.createVertexBuffer(4, 6);
			var ib = c3.createIndexBuffer(6);
			ib.uploadFromArray([0, 1, 2, 0, 2, 3]);
			c3.setTextureAt(0, null);
			c3.setVertexBufferAt(0, vb, 0, VertexFormat.Float32x2);
			c3.setVertexBufferAt(1, vb, 2, VertexFormat.Float32x4);

			vb.uploadFromFloat32Array(quad(10, 110, 90, 190, 0, 1, 1));
			c3.drawTriangles(ib, proj);

			vb.uploadFromFloat32Array(quad(110, 110, 190, 190, 1, 0.5, 0));
			c3.drawTriangles(ib, proj);

			// Top edge only. The lower edge has to survive from the previous upload.
			vb.uploadFromFloat32Array(new Float32Array([
				310, 110, 0.6, 0.2, 1, 1,
				390, 110, 0.6, 0.2, 1, 1
			]), 0, 2);
			c3.drawTriangles(ib, proj);

			c3.endRenderPass();
			vb.dispose();
			ib.dispose();
			yellow.dispose();
			cv.dispose();
		}, 0x000000);

		expect("first flush (red)", 20, 80, 0xFF0000);
		expect("sprite over first flush (yellow)", 80, 50, 0xFFFF00);
		expect("second flush over sprite (green)", 95, 50, 0x00FF00);
		expect("grown flush (blue)", 131, 11, 0x0000FF);
		expect("flush after growth, cached shape (magenta)", 260, 50, 0xFF00FF);
		expect("first upload (cyan)", 50, 150, 0x00FFFF);
		expect("second upload (orange)", 150, 150, 0xFF8000);
		expect("partial upload keeps lower edge", 195, 186, 0xFF8000, 48);
		expect("partial upload top edge (purple)", 330, 112, 0x9933FF, 48);
		expect("background between quads", 100, 150, 0x000000);

		if (failures.length > 0) {
			for (f in failures) {
				Sys.println("FAIL " + f);
				Snapshot.event('error multi-flush-scene $f');
			}
			Sys.exit(1);
		}
		Sys.println("multi-flush-scene: all checks passed");
	}
}
