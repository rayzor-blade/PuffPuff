import Harness.BenchCase;
import ash.simd.Vec;
import lime.graphics.Image;
import lime.math.Matrix3;
import lime.math.Matrix4;
import lime.math.Rectangle;
import lime.math.Vector2;
import lime.math.Vector4;
import lime.utils.Float32Array;
import puffpuff.canvas.Affine;
import puffpuff.canvas.Canvas2D;
import puffpuff.canvas.Mesh;
import puffpuff.canvas.Paint;
import puffpuff.canvas.Path;
import puffpuff.canvas.Stroke;
import puffpuff.gpu.QuadBatcher;
import puffpuff.gpu.TriangleBatcher;
import puffpuff.gpu.WgpuContext;
import puffpuff.snapshot.Snapshot;
import puffpuff.text.FontAtlas;
#if openfl_wgpu
import openfl.text.TextField;
import openfl.text.TextFormat;
#end

private enum LabelMode {
	Cached;
	Fresh;
	Whole;
}

/** Every benchmark case. Names are `area.subject[.variant]`, and the area is the filter prefix. **/
@:access(puffpuff.canvas.Canvas2D)
class Cases {
	static inline var W = 512;
	static inline var H = 512;

	public static function all():Array<BenchCase> {
		var all = math().concat(simd()).concat(image()).concat(text()).concat(engine()).concat(gpu());
		#if openfl_wgpu
		all = all.concat(openflText());
		#end
		return all;
	}

	static var seed = 20240601;

	static function rnd():Float {
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
		return (seed % 2000) / 1000.0 - 1.0;
	}

	static function rotationZ(theta:Float):Array<Float> {
		var c = Math.cos(theta), s = Math.sin(theta);
		return [c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
	}

	/** `a = a * b` on 16-float row-major matrices, in double arithmetic. **/
	static function mul(a:Array<Float>, b:Array<Float>):Array<Float> {
		var r = [for (i in 0...16) 0.0];
		for (row in 0...4)
			for (col in 0...4) {
				var s = 0.0;
				for (k in 0...4) s += a[row * 4 + k] * b[k * 4 + col];
				r[row * 4 + col] = s;
			}
		return r;
	}

	static function worst(a:Float32Array, e:Array<Float>):Float {
		var d = 0.0;
		for (i in 0...e.length) d = Math.max(d, Math.abs(a[i] - e[i]));
		return d;
	}

	static function appendScalar(a:Float32Array, b:Float32Array):Void {
		var a00 = a[0], a01 = a[1], a02 = a[2], a03 = a[3];
		var a10 = a[4], a11 = a[5], a12 = a[6], a13 = a[7];
		var a20 = a[8], a21 = a[9], a22 = a[10], a23 = a[11];
		var a30 = a[12], a31 = a[13], a32 = a[14], a33 = a[15];
		var b00 = b[0], b01 = b[1], b02 = b[2], b03 = b[3];
		var b10 = b[4], b11 = b[5], b12 = b[6], b13 = b[7];
		var b20 = b[8], b21 = b[9], b22 = b[10], b23 = b[11];
		var b30 = b[12], b31 = b[13], b32 = b[14], b33 = b[15];
		a[0] = a00 * b00 + a01 * b10 + a02 * b20 + a03 * b30;
		a[1] = a00 * b01 + a01 * b11 + a02 * b21 + a03 * b31;
		a[2] = a00 * b02 + a01 * b12 + a02 * b22 + a03 * b32;
		a[3] = a00 * b03 + a01 * b13 + a02 * b23 + a03 * b33;
		a[4] = a10 * b00 + a11 * b10 + a12 * b20 + a13 * b30;
		a[5] = a10 * b01 + a11 * b11 + a12 * b21 + a13 * b31;
		a[6] = a10 * b02 + a11 * b12 + a12 * b22 + a13 * b32;
		a[7] = a10 * b03 + a11 * b13 + a12 * b23 + a13 * b33;
		a[8] = a20 * b00 + a21 * b10 + a22 * b20 + a23 * b30;
		a[9] = a20 * b01 + a21 * b11 + a22 * b21 + a23 * b31;
		a[10] = a20 * b02 + a21 * b12 + a22 * b22 + a23 * b32;
		a[11] = a20 * b03 + a21 * b13 + a22 * b23 + a23 * b33;
		a[12] = a30 * b00 + a31 * b10 + a32 * b20 + a33 * b30;
		a[13] = a30 * b01 + a31 * b11 + a32 * b21 + a33 * b31;
		a[14] = a30 * b02 + a31 * b12 + a32 * b22 + a33 * b32;
		a[15] = a30 * b03 + a31 * b13 + a32 * b23 + a33 * b33;
	}

	static function math():Array<BenchCase> {
		var rot = new Float32Array(rotationZ(0.01));
		var m4 = new Matrix4();
		var m4s:Float32Array = new Matrix4();
		var rotM = new Matrix4(rot);

		function m4Check(f:Float32Array->Float32Array->Void):Void->Null<String> {
			return () -> {
				var av = [for (i in 0...16) rnd()], bv = [for (i in 0...16) rnd()];
				var a = new Float32Array(av);
				f(a, new Float32Array(bv));
				var d = worst(a, mul(av, bv));
				return d < 1e-4 ? null : 'max error $d against a double-precision product';
			};
		}

		var m3 = new Matrix3(1, 0, 0, 1, 12345.678, 9876.543);
		var m3r = new Matrix3(Math.cos(0.01), Math.sin(0.01), -Math.sin(0.01), Math.cos(0.01), 0, 0);
		var v1 = new Vector4(1, 2, 3, 1), v2 = new Vector4(4, 5, 6, 1), vout = new Vector4();
		var arr = new Float32Array(1024);
		var acc = 0.0;

		return [
			{
				name: "math.matrix4.append",
				run: () -> m4.append(rotM),
				check: m4Check((a, b) -> (cast a : Matrix4).append(new Matrix4(b))),
				maxAllocPerOp: 0
			},
			{
				name: "math.matrix4.append.scalar",
				run: () -> appendScalar(m4s, rot),
				check: m4Check(appendScalar),
				maxAllocPerOp: 0
			},
			{
				name: "math.matrix3.concat",
				run: () -> m3.concat(m3r),
				check: () -> {
					var x = new Matrix3(1, 0, 0, 1, 12345.678, 9876.543);
					x.concat(new Matrix3(1.0001, 0, 0, 0.9999, 0.37, 0.19));
					var wx = 12345.678 * 1.0001 + 0.37, wy = 9876.543 * 0.9999 + 0.19;
					return (Math.abs(x.tx - wx) < 1e-9 && Math.abs(x.ty - wy) < 1e-9) ? null : 'translation drifted: ${x.tx}, ${x.ty}';
				},
				maxAllocPerOp: 0
			},
			{
				name: "math.vector4.add",
				run: () -> v1.add(v2, vout),
				check: () -> {
					v1.add(v2, vout);
					return (vout.x == 5 && vout.y == 7 && vout.z == 9 && vout.w == 2) ? null : 'got ${vout.x},${vout.y},${vout.z},${vout.w}';
				},
				maxAllocPerOp: 0
			},
			{
				name: "math.float32array.readwrite",
				ops: 2048,
				run: () -> {
					for (i in 0...1024) arr[i] = i * 0.5;
					for (i in 0...1024) acc += arr[i];
				},
				check: () -> {
					for (i in 0...1024) arr[i] = i * 0.5;
					return arr[1023] == 511.5 ? null : 'arr[1023] = ${arr[1023]}';
				},
				maxAllocPerOp: 0
			}
		];
	}

	static function simd():Array<BenchCase> {
		var n = 4096;
		var a = new hl.Bytes(n * 4), b = new hl.Bytes(n * 4), d = new hl.Bytes(n * 4);
		for (i in 0...n) {
			a.setF32(i * 4, i * 0.25);
			b.setF32(i * 4, 1 + i * 0.5);
		}
		function sumCheck():Null<String> {
			for (i in 0...n) {
				var want = i * 0.25 + 1 + i * 0.5;
				if (Math.abs(d.getF32(i * 4) - want) > 1e-2) return 'lane $i is ${d.getF32(i * 4)}, want $want';
			}
			return null;
		}
		return [
			{
				name: "simd.batch.add.inplace",
				ops: n,
				run: () -> {
					var i = 0;
					while (i < n) {
						Vec.f32x4Add(d, i * 4, a, i * 4, b, i * 4);
						i += 4;
					}
				},
				check: () -> {
					var i = 0;
					while (i < n) {
						Vec.f32x4Add(d, i * 4, a, i * 4, b, i * 4);
						i += 4;
					}
					return sumCheck();
				},
				maxAllocPerOp: 0
			},
			{
				name: "simd.batch.add.scalar",
				ops: n,
				run: () -> for (i in 0...n) d.setF32(i * 4, a.getF32(i * 4) + b.getF32(i * 4)),
				check: () -> {
					for (i in 0...n) d.setF32(i * 4, a.getF32(i * 4) + b.getF32(i * 4));
					return sumCheck();
				},
				maxAllocPerOp: 0
			}
		];
	}

	static function shapePaths(count:Int):Array<Path> {
		var paths = [];
		for (i in 0...count) {
			var x = 20 + (i % 20) * 24, y = 20 + Std.int(i / 20) * 24;
			paths.push(switch (i % 4) {
				case 0: new Path().circle(x, y, 9);
				case 1: new Path().roundedRect(x - 9, y - 9, 18, 18, 4);
				case 2: new Path().moveTo(x - 9, y + 9).lineTo(x, y - 9).lineTo(x + 9, y + 9).close();
				default: new Path().moveTo(x - 9, y).cubicTo(x - 3, y - 12, x + 3, y + 12, x + 9, y);
			});
		}
		return paths;
	}

	static function drawShapes(cv:Canvas2D, paths:Array<Path>, dx:Float):Void {
		var fill = Paint.solid(0x38BDF8), line = Paint.solid(0xF472B6), stroke = new Stroke(2);
		var shift = Affine.translation(dx, 0);
		cv.begin();
		for (i in 0...paths.length) {
			if (i % 4 == 3) cv.stroke(paths[i], stroke, line, shift) else cv.fill(paths[i], fill, NonZero, shift);
		}
	}

	static function meshHash(cv:Canvas2D):String {
		return Harness.fnv(cv.mesh.bytes, 0, cv.mesh.length);
	}

	/** Pixel operations of `lime.graphics.Image` on a 256 x 256 image. `ops` is pixels. **/
	static function image():Array<BenchCase> {
		var n = 256;
		var px = n * n;
		var area = new Rectangle(0, 0, n, n);
		var origin = new Vector2(0, 0);
		var src = new Image(null, 0, 0, n, n, 0x336699FF);
		var alpha = new Image(null, 0, 0, n, n, 0x33669980);
		var dst = new Image(null, 0, 0, n, n, 0x00000000);
		var same = (img:Image, x:Int, y:Int, rgba:Int) -> img.getPixel32(x, y, lime.graphics.PixelFormat.RGBA32) == rgba;
		return [
			{
				name: "image.fillRect",
				ops: px,
				run: () -> dst.fillRect(area, 0xFF8040FF),
				check: () -> {
					dst.fillRect(area, 0xFF8040FF);
					for (pt in [[0, 0], [n - 1, 0], [n >> 1, n >> 1], [n - 1, n - 1]]) {
						if (!same(dst, pt[0], pt[1], 0xFF8040FF)) return 'pixel ${pt[0]},${pt[1]} not filled';
					}
					return null;
				},
				checksum: () -> Harness.fnv(dst.buffer.data.toBytes(), 0, px * 4)
			},
			{
				name: "image.copyPixels",
				ops: px,
				run: () -> dst.copyPixels(src, area, origin),
				check: () -> {
					dst.fillRect(area, 0);
					dst.copyPixels(src, area, origin);
					for (pt in [[0, 0], [n - 1, n - 1], [n >> 1, 3]]) {
						if (!same(dst, pt[0], pt[1], 0x336699FF)) return 'pixel ${pt[0]},${pt[1]} not copied';
					}
					return null;
				},
				checksum: () -> Harness.fnv(dst.buffer.data.toBytes(), 0, px * 4)
			},
			{
				name: "image.copyPixels.merge",
				ops: px,
				run: () -> dst.copyPixels(alpha, area, origin, null, null, true),
				check: () -> {
					dst.fillRect(area, 0xFFFFFFFF);
					dst.copyPixels(alpha, area, origin, null, null, true);
					var c = dst.getPixel32(5, 5, lime.graphics.PixelFormat.RGBA32);
					if ((c & 0xFF) != 0xFF) return 'merged alpha over opaque should stay opaque, got ${StringTools.hex(c, 8)}';
					return null;
				},
				checksum: () -> Harness.fnv(dst.buffer.data.toBytes(), 0, px * 4)
			},
			{
				name: "image.getPixels",
				ops: px,
				run: () -> src.getPixels(area),
				check: () -> {
					var b = src.getPixels(area);
					if (b.length != px * 4) return 'got ${b.length} bytes';
					return b.get(0) == 0x33 && b.get(1) == 0x66 && b.get(2) == 0x99 && b.get(3) == 0xFF ? null : 'first pixel bytes wrong';
				},
				checksum: () -> {
					var b = src.getPixels(area);
					return Harness.fnv(b, 0, b.length);
				}
			},
			{
				name: "image.setPixel32.row",
				ops: n,
				run: () -> for (x in 0...n) dst.setPixel32(x, 7, 0xAABBCCDD),
				check: () -> {
					for (x in 0...n) dst.setPixel32(x, 7, 0xAABBCCDD);
					return same(dst, 0, 7, 0xAABBCCDD) && same(dst, n - 1, 7, 0xAABBCCDD) ? null : 'row not written';
				},
				checksum: () -> Harness.fnv(dst.buffer.data.toBytes(), 0, px * 4)
			}
		];
	}

	static function engine():Array<BenchCase> {
		var cold = shapePaths(300);
		var warm = shapePaths(64);
		var warmCanvas = new Canvas2D(null);
		var frame = 0;

		var quads = new QuadBatcher(null, 20000);
		var triangles = new TriangleBatcher(null, 60000);

		var vertices = 3000;
		var source = new Mesh();
		for (i in 0...vertices) source.vertex(rnd() * 100, rnd() * 100, 1, 1e6, 1e6, 1e6, 1e6);
		var srcBytes = source.copyRange(0, vertices);
		var target = new Mesh();
		target.paint = 7;

		return [
			{
				name: "canvas2d.build.cold",
				ops: cold.length,
				run: () -> drawShapes(new Canvas2D(null), cold, 0),
				check: () -> {
					var cv = new Canvas2D(null);
					drawShapes(cv, cold, 0);
					return (cv.vertexCount > 0 && cv.drawCount == cold.length) ? null : 'draws ${cv.drawCount} of ${cold.length}, vertices ${cv.vertexCount}';
				},
				checksum: () -> {
					var cv = new Canvas2D(null);
					drawShapes(cv, cold, 0);
					return meshHash(cv);
				}
			},
			{
				name: "canvas2d.build.reused",
				ops: warm.length,
				setup: () -> for (i in 0...3) drawShapes(warmCanvas, warm, 0),
				run: () -> drawShapes(warmCanvas, warm, (frame++ & 7) * 0.5),
				check: () -> {
					drawShapes(warmCanvas, warm, 0);
					return warmCanvas.reused == warm.length ? null : 'reused ${warmCanvas.reused} of ${warm.length} cached shapes';
				},
				checksum: () -> {
					drawShapes(warmCanvas, warm, 0);
					return meshHash(warmCanvas);
				}
			},
			{
				name: "quadbatcher.addQuad",
				ops: 10000,
				run: () -> {
					quads.begin(null);
					for (i in 0...10000) quads.addQuad(16, 0, 0, 16, (i % 100) * 5.0, Std.int(i / 100) * 5.0, 0, 0, 1, 1, 1.0, 0xFFFFFF);
				},
				check: () -> {
					quads.begin(null);
					for (i in 0...10000) quads.addQuad(16, 0, 0, 16, (i % 100) * 5.0, Std.int(i / 100) * 5.0, 0, 0, 1, 1, 1.0, 0xFFFFFF);
					var f:Float32Array = @:privateAccess quads.instanceData;
					return (f[0] == 16 && f[4] == 0 && f[(9999 * 12) + 5] == 99 * 5.0) ? null : 'unexpected instance data';
				},
				checksum: () -> {
					var f:Float32Array = @:privateAccess quads.instanceData;
					return Harness.fnv(f.buffer, f.byteOffset, 10000 * 48);
				},
				maxAllocPerOp: 0
			},
			{
				name: "trianglebatcher.vertex",
				ops: 10000,
				run: () -> {
					triangles.begin(null, false);
					for (i in 0...10000) quadAsTriangles(triangles, (i % 100) * 5.0, Std.int(i / 100) * 5.0);
				},
				check: () -> {
					triangles.begin(null, false);
					for (i in 0...10000) quadAsTriangles(triangles, (i % 100) * 5.0, Std.int(i / 100) * 5.0);
					var b = triangles.bytes;
					return (triangles.length == 10000 * 6 * TriangleBatcher.BYTES && b.getFloat(0) == 0 && b.getFloat(4) == 0
						&& b.getFloat(8) == 0 && b.getFloat(16) == 1 && b.getInt32(20) == 0xFFFFFFFF) ? null : 'unexpected vertex data';
				},
				checksum: () -> Harness.fnv(triangles.bytes, 0, triangles.length),
				maxAllocPerOp: 0
			},
			{
				name: "mesh.appendTranslated",
				ops: vertices,
				run: () -> {
					target.clear();
					target.appendTranslated(srcBytes, 1.5, 2.5);
				},
				check: () -> {
					target.clear();
					target.appendTranslated(srcBytes, 1.5, 2.5);
					for (i in [0, 1, vertices - 1]) {
						var b = i * Mesh.BYTES;
						if (Math.abs(target.bytes.getFloat(b) - (srcBytes.getFloat(b) + 1.5)) > 1e-4) return 'x of vertex $i not shifted';
						if (Math.abs(target.bytes.getFloat(b + 4) - (srcBytes.getFloat(b + 4) + 2.5)) > 1e-4) return 'y of vertex $i not shifted';
						if (target.bytes.getFloat(b + 12) != 7) return 'paint of vertex $i not restamped';
					}
					return null;
				},
				checksum: () -> Harness.fnv(target.bytes, 0, target.length),
				maxAllocPerOp: 0
			}
		];
	}

	/** 8 pixel square at `x`, `y` as two triangles (six vertices). **/
	static inline function quadAsTriangles(t:TriangleBatcher, x:Float, y:Float):Void {
		t.vertex(x, y, 0, 0, 1, 0xFFFFFFFF);
		t.vertex(x + 8, y, 1, 0, 1, 0xFFFFFFFF);
		t.vertex(x, y + 8, 0, 1, 1, 0xFFFFFFFF);
		t.vertex(x, y + 8, 0, 1, 1, 0xFFFFFFFF);
		t.vertex(x + 8, y, 1, 0, 1, 0xFFFFFFFF);
		t.vertex(x + 8, y + 8, 1, 1, 1, 0xFFFFFFFF);
	}

	/** The sprite frame's 5000 squares as 30000 triangle vertices, to compare the triangle path with instanced quads. **/
	static function triangleDraw():puffpuff.gpu.WgpuContext3D->Void {
		var batcher:TriangleBatcher = null;
		var texture:puffpuff.gpu.WgpuContext3D.WgpuTexture = null;
		var proj = new Matrix4();
		proj.createOrtho(0, W, H, 0, -1, 1);
		return c3 -> {
			if (batcher == null) {
				batcher = new TriangleBatcher(c3, 30000);
				texture = c3.createTexture(4, 4);
				var px = haxe.io.Bytes.alloc(64);
				for (i in 0...16) {
					px.set(i * 4, 255);
					px.set(i * 4 + 1, 200);
					px.set(i * 4 + 2, 60);
					px.set(i * 4 + 3, 255);
				}
				texture.uploadFromBytes(px);
			}
			batcher.begin(texture, false);
			for (i in 0...5000) quadAsTriangles(batcher, (i % 64) * 8.0, Std.int(i / 64) * 6.0);
			batcher.flush(proj);
		};
	}

	/** Persistent offscreen context. A frame is begin, draw, end, and `readback` adds the copy to the CPU. **/
	static function gpuFrame(name:String, readback:Bool, makeDraw:Void->(puffpuff.gpu.WgpuContext3D->Void), ?expect:Void->Null<String>, stable = true):BenchCase {
		var draw = makeDraw();
		var off:puffpuff.snapshot.Offscreen = null, texture:gpu.GpuTexture = 0, view:gpu.GpuTextureView = 0, ctx:WgpuContext = null;
		var pixels:Null<haxe.io.Bytes> = null;
		function frame():Void {
			ctx.beginOffscreen(view, W, H);
			ctx.clear(0.06, 0.07, 0.11, 1.0);
			var c3 = ctx.context3D;
			c3.beginRenderPass(0.06, 0.07, 0.11, 1.0);
			draw(c3);
			c3.endRenderPass();
			ctx.endOffscreen();
			if (readback) pixels = off.readRgba8(texture, W, H);
		}
		return {
			name: name,
			sampleMs: 60,
			setup: () -> {
				if (off != null) return;
				off = Snapshot.renderer();
				texture = off.createTexture(W, H);
				view = texture.createView(new gpu.GpuTextureViewDescriptor());
				ctx = WgpuContext.createOffscreen(view, W, H);
				ctx.endOffscreen();
			},
			run: frame,
			check: readback || expect != null ? () -> {
				frame();
				var problem = expect != null ? expect() : null;
				if (problem != null || !readback) return problem;
				var lit = 0;
				var i = 0;
				while (i < pixels.length) {
					if (pixels.get(i) != 15) lit++;
					i += 16;
				}
				return lit > 1000 ? null : 'frame looks empty ($lit sampled pixels differ from the clear colour)';
			} : null,
			checksum: readback && stable ? () -> {
				frame();
				var hash = Harness.fnv(pixels, 0, pixels.length);
				var dump = Sys.getEnv("BENCH_DUMP");
				if (dump != null && dump != "") sys.io.File.saveBytes('$dump/$name-$hash.raw', pixels);
				return hash;
			} : null
		};
	}

	static var lastCanvas:Canvas2D;

	/** All 300 shapes must produce vertices, since a silent drop still leaves a valid-looking frame. **/
	static function vectorsDrawn():Null<String> {
		var n = lastCanvas == null ? 0 : lastCanvas.drawCount;
		return n == 300 ? null : 'only $n of 300 shapes produced vertices';
	}

	static function vectorDraw():puffpuff.gpu.WgpuContext3D->Void {
		var paths = shapePaths(300);
		var canvas:Canvas2D = null;
		var proj = new Matrix4();
		proj.createOrtho(0, W, H, 0, -1, 1);
		return c3 -> {
			if (canvas == null) canvas = new Canvas2D(c3);
			lastCanvas = canvas;
			drawShapes(canvas, paths, 0);
			canvas.flush(proj);
		};
	}

	static function spriteDraw():puffpuff.gpu.WgpuContext3D->Void {
		var batcher:QuadBatcher = null;
		var texture:puffpuff.gpu.WgpuContext3D.WgpuTexture = null;
		var proj = new Matrix4();
		proj.createOrtho(0, W, H, 0, -1, 1);
		return c3 -> {
			if (batcher == null) {
				batcher = new QuadBatcher(c3, 6000);
				texture = c3.createTexture(4, 4);
				var px = haxe.io.Bytes.alloc(64);
				for (i in 0...16) {
					px.set(i * 4, 255);
					px.set(i * 4 + 1, 200);
					px.set(i * 4 + 2, 60);
					px.set(i * 4 + 3, 255);
				}
				texture.uploadFromBytes(px);
			}
			batcher.begin(texture);
			for (i in 0...5000) batcher.addQuad(8, 0, 0, 8, (i % 64) * 8.0, Std.int(i / 64) * 6.0);
			batcher.flush(proj);
		};
	}

	#if openfl_wgpu
	/** OpenFL's own `TextField` on PuffPuff's Lime layer, with the same layout the OpenFL baseline app times. **/
	static function openflText():Array<BenchCase> {
		var format = new TextFormat("_sans", 14, 0xFFFFFF);
		var paragraph = "The quick brown fox jumps over the lazy dog while the five boxing wizards jump quickly, and pack my box with five dozen liquor jugs. ";
		function field(text:String):TextField {
			var tf = new TextField();
			tf.defaultTextFormat = format;
			tf.wordWrap = true;
			tf.width = 300;
			tf.text = text;
			return tf;
		}
		return [
			{
				name: "openfl.textfield.layout.paragraph",
				run: () -> {
					var tf = field(paragraph + (labelCounter++));
					tf.numLines;
					tf.textWidth;
				},
				check: () -> {
					var tf = field(paragraph + "0");
					return tf.numLines == 3 && tf.textHeight == 48 && tf.textWidth > 250 && tf.textWidth < 300 ? null : 'laid out as ${tf.numLines} lines, ${tf.textWidth} x ${tf.textHeight}';
				},
				checksum: () -> {
					var tf = field(paragraph + "0");
					return tf.numLines + ":" + tf.textWidth + ":" + tf.textHeight;
				}
			}
		];
	}
	#end

	static inline var LABELS = 200;
	static final PARAGRAPH = "The quick brown fox jumps over the lazy dog while the five boxing wizards jump quickly, and pack my box with five dozen liquor jugs. 0";

	static var labelCounter = 0;

	static function label(n:Int):String
		return "Label " + n + ": the quick brown fox";

	/**
		Text shaping and the screen of 200 labels that OpenFL's text benchmark draws. `ops` is paragraphs or labels. The
		`.whole` cases shape every line whole instead of from words shaped once. They are the reference the default is checked
		against, and show what it saves.
	**/
	static function text():Array<BenchCase> {
		var atlas = FontAtlas.getDefault();
		var style = {size: 14.0, family: "Arimo"};
		function whole(f:Void->Void):Void {
			FontAtlas.wordCache(false);
			f();
			FontAtlas.wordCache(true);
		}
		function agrees(text:String):Null<String> {
			var reference:puffpuff.text.FontAtlas.PreparedRun = null;
			whole(() -> reference = atlas.prepare(text, style));
			var composed = atlas.prepare(text, style);
			if (reference.glyphs.length != composed.glyphs.length) return 'words give ${composed.glyphs.length} glyphs, whole lines ${reference.glyphs.length}';
			if (Math.abs(reference.width - composed.width) > 0.05) return 'words give width ${composed.width}, whole lines ${reference.width}';
			for (i in 0...reference.glyphs.length)
				if (Math.abs(reference.glyphs[i].x - composed.glyphs[i].x) > 1.0) return 'glyph $i is ${composed.glyphs[i].x}, whole lines ${reference.glyphs[i].x}';
			return null;
		}
		return [
			{
				name: "text.shape.paragraph",
				run: () -> atlas.prepare(PARAGRAPH + (labelCounter++), style),
				check: () -> agrees(PARAGRAPH + "7")
			},
			{
				name: "text.shape.paragraph.whole",
				run: () -> whole(() -> atlas.prepare(PARAGRAPH + (labelCounter++), style))
			},
			{
				name: "text.shape.labels200",
				ops: LABELS,
				run: () -> for (i in 0...LABELS) atlas.prepare(label(labelCounter++), style),
				check: () -> agrees(label(7))
			},
			{
				name: "text.shape.labels200.whole",
				ops: LABELS,
				run: () -> whole(() -> for (i in 0...LABELS) atlas.prepare(label(labelCounter++), style))
			},
			{
				name: "text.measure.labels200",
				ops: LABELS,
				run: () -> for (i in 0...LABELS) atlas.measureText(label(labelCounter++), 14, style)
			}
		];
	}

	/**
		200 labels drawn every frame, either from runs shaped once (`Cached`) or with new text each frame (`Fresh`). `Fresh`
		shapes whole lines when `Whole` switches the word cache off.
	**/
	static function labelsDraw(mode:LabelMode):Void->(puffpuff.gpu.WgpuContext3D->Void) {
		return () -> {
			var proj = new Matrix4();
			proj.createOrtho(0, W, H, 0, -1, 1);
			var batcher:QuadBatcher = null;
			var atlas = FontAtlas.getDefault();
			var style = {size: 14.0, family: "Arimo"};
			var runs = [for (i in 0...LABELS) atlas.prepare(label(i), style)];
			return c3 -> {
				if (batcher == null) batcher = new QuadBatcher(c3, 4096);
				var texture = atlas.upload(c3);
				batcher.begin(texture);
				FontAtlas.wordCache(mode != Whole);
				for (i in 0...LABELS) {
					var x = (i % 4) * 128 + 4.0;
					var y = Std.int(i / 4) * 10 + 14.0;
					if (mode == Cached) {
						atlas.sync(c3);
						var invW = 1.0 / texture.width, invH = 1.0 / texture.height;
						for (g in runs[i].glyphs)
							if (g.width > 0 && g.height > 0 && !g.isColor)
								batcher.addQuad(g.width, 0, 0, g.height, Math.round(x + g.x), Math.round(y + g.y), g.u0 * invW, g.v0 * invH, (g.u1 - g.u0) * invW,
									(g.v1 - g.v0) * invH, 1.0, 0xFFFFFF);
					} else {
						atlas.drawText(batcher, label(labelCounter++), x, y, 14.0, 0xFFFFFF, 1.0, style);
					}
				}
				FontAtlas.wordCache(true);
				batcher.flush(proj);
			};
		};
	}

	static function gpu():Array<BenchCase> {
		return [
			gpuFrame("gpu.frame.vectors.submit", false, vectorDraw, vectorsDrawn),
			gpuFrame("gpu.frame.vectors.readback", true, vectorDraw, vectorsDrawn),
			gpuFrame("gpu.frame.sprites.submit", false, spriteDraw),
			gpuFrame("gpu.frame.sprites.readback", true, spriteDraw),
			gpuFrame("gpu.frame.triangles.submit", false, triangleDraw),
			gpuFrame("gpu.frame.triangles.readback", true, triangleDraw),
			gpuFrame("gpu.frame.text.static.submit", false, labelsDraw(Cached)),
			gpuFrame("gpu.frame.text.static.readback", true, labelsDraw(Cached)),
			gpuFrame("gpu.frame.text.dynamic.submit", false, labelsDraw(Fresh)),
			gpuFrame("gpu.frame.text.dynamic.readback", true, labelsDraw(Fresh), null, false),
			gpuFrame("gpu.frame.text.dynamic.whole.submit", false, labelsDraw(Whole)),
			gpuFrame("gpu.frame.text.dynamic.whole.readback", true, labelsDraw(Whole), null, false)
		];
	}
}
