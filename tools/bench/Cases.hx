import Harness.BenchCase;
import ash.simd.Vec;
import lime.math.Matrix3;
import lime.math.Matrix4;
import lime.math.Vector4;
import lime.utils.Float32Array;
import puffpuff.canvas.Affine;
import puffpuff.canvas.Canvas2D;
import puffpuff.canvas.Mesh;
import puffpuff.canvas.Paint;
import puffpuff.canvas.Path;
import puffpuff.canvas.Stroke;
import puffpuff.gpu.QuadBatcher;
import puffpuff.gpu.WgpuContext;
import puffpuff.snapshot.Snapshot;

/** Every benchmark case. Names are `area.subject[.variant]`, and the area is the filter prefix. **/
@:access(puffpuff.canvas.Canvas2D)
class Cases {
	static inline var W = 512;
	static inline var H = 512;

	public static function all():Array<BenchCase> {
		return math().concat(simd()).concat(engine()).concat(gpu());
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

	static function engine():Array<BenchCase> {
		var cold = shapePaths(300);
		var warm = shapePaths(64);
		var warmCanvas = new Canvas2D(null);
		var frame = 0;

		var quads = new QuadBatcher(null, 20000);

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

	/** Persistent offscreen context. A frame is begin, draw, end, and `readback` adds the copy to the CPU. **/
	static function gpuFrame(name:String, readback:Bool, makeDraw:Void->(puffpuff.gpu.WgpuContext3D->Void), ?expect:Void->Null<String>):BenchCase {
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
			checksum: readback ? () -> {
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

	static function gpu():Array<BenchCase> {
		return [
			gpuFrame("gpu.frame.vectors.submit", false, vectorDraw, vectorsDrawn),
			gpuFrame("gpu.frame.vectors.readback", true, vectorDraw, vectorsDrawn),
			gpuFrame("gpu.frame.sprites.submit", false, spriteDraw),
			gpuFrame("gpu.frame.sprites.readback", true, spriteDraw)
		];
	}
}
