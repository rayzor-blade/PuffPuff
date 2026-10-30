import lime.math.Matrix4;
import lime.math.Vector4;
import lime.utils.Float32Array;

class SimdOpBench {
	// Scalar reference with the same operand roles as Matrix4.append: a = a * b, 16 floats each.
	static function scalarAppend(a:Float32Array, b:Float32Array):Void {
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

	static function time(label:String, reps:Int, f:Void->Void):Float {
		f(); // warm up
		var best = 1e9;
		for (run in 0...5) {
			var t0 = haxe.Timer.stamp();
			for (i in 0...reps) f();
			var dt = haxe.Timer.stamp() - t0;
			if (dt < best) best = dt;
		}
		var ns = best / reps * 1e9;
		Sys.println('$label: ${Math.round(ns * 10) / 10} ns/op');
		return ns;
	}

	static function main() {
		var m1 = new Matrix4(), m2 = new Matrix4();
		m1.createOrtho(0, 800, 600, 0, -1, 1);
		m2.createOrtho(0, 640, 480, 0, -1, 1);
		var f1:Float32Array = m1, f2:Float32Array = m2;
		var n = 1000000;
		var simd = time("Matrix4.append (ash-simd)", n, () -> m1.append(m2));
		var scalar = time("scalar 4x4 multiply     ", n, () -> scalarAppend(f1, f2));
		Sys.println('simd/scalar time ratio: ${Math.round(simd / scalar * 100) / 100}');

		var v1 = new Vector4(1, 2, 3, 1), v2 = new Vector4(4, 5, 6, 1);
		var vs = time("Vector4.add (ash-simd)   ", 5000000, () -> v1.add(v2));
		var x = 0.0;
		var sc = time("scalar vec add (4 floats)", 5000000, () -> {
			x = v1.x + v2.x;
			x += v1.y + v2.y;
			x += v1.z + v2.z;
			x += v1.w + v2.w;
		});
		Sys.println('vec simd/scalar time ratio: ${Math.round(vs / sc * 100) / 100} ($x)');
	}
}
