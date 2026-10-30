import lime.math.Matrix3;
import lime.math.Matrix4;
import lime.math.Vector4;
import lime.utils.Float32Array;

/**
	Asserts that Matrix4's ash-simd multiply agrees with scalar arithmetic, and that Matrix3 and Vector4
	(object-field types, kept scalar) keep full double precision.
**/
class SimdCheck {
	static function scalarMul(a:Array<Float>, b:Array<Float>):Array<Float> {
		var r = [for (i in 0...16) 0.0];
		for (row in 0...4)
			for (col in 0...4) {
				var s = 0.0;
				for (k in 0...4)
					s += a[row * 4 + k] * b[k * 4 + col];
				r[row * 4 + col] = s;
			}
		return r;
	}

	static function main():Void {
		var seed = 12345;
		inline function rnd():Float {
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
			return (seed % 2000) / 1000.0 - 1.0;
		}

		var failures = 0;
		for (t in 0...200) {
			var a = [for (i in 0...16) rnd()];
			var b = [for (i in 0...16) rnd()];
			var m = new Matrix4(new Float32Array(a));
			m.append(new Matrix4(new Float32Array(b)));
			var expected = scalarMul(a, b);
			var worst = 0.0;
			for (i in 0...16)
				worst = Math.max(worst, Math.abs((cast m : Float32Array)[i] - expected[i]));
			if (worst > 1e-4) failures++;
		}
		if (failures > 0) {
			Sys.println('FAIL Matrix4.append differs from scalar multiply in $failures of 200 cases');
			Sys.exit(1);
		}

		var s = new Vector4(1, 2, 3, 1).add(new Vector4(4, 5, 6, 1));
		if (s.x != 5 || s.y != 7 || s.z != 9 || s.w != 2) {
			Sys.println('FAIL Vector4.add gave ${s.x},${s.y},${s.z},${s.w}');
			Sys.exit(1);
		}

		// Large translation: float32 lanes would lose about 3e-4 here; doubles stay exact to rounding.
		var m3 = new Matrix3(1, 0, 0, 1, 12345.678, 9876.543);
		m3.concat(new Matrix3(1.0001, 0, 0, 0.9999, 0.37, 0.19));
		var wantTx = 12345.678 * 1.0001 + 0.37, wantTy = 9876.543 * 0.9999 + 0.19;
		if (Math.abs(m3.tx - wantTx) > 1e-9 || Math.abs(m3.ty - wantTy) > 1e-9) {
			Sys.println('FAIL Matrix3.concat lost precision: tx ${m3.tx} want $wantTx, ty ${m3.ty} want $wantTy');
			Sys.exit(1);
		}
		Sys.println("simd-check: all checks passed");
	}
}
