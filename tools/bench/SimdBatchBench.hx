import ash.simd.Vec;

class SimdBatchBench {
	static function time(label:String, reps:Int, f:Void->Void):Float {
		f();
		var best = 1e9;
		for (run in 0...5) {
			var t0 = haxe.Timer.stamp();
			for (i in 0...reps) f();
			var dt = haxe.Timer.stamp() - t0;
			if (dt < best) best = dt;
		}
		var ns = best / reps * 1e9;
		Sys.println('$label: ${Math.round(ns)} ns/op');
		return ns;
	}

	static function main() {
		var n = 4096; // floats
		var a = new hl.Bytes(n * 4), b = new hl.Bytes(n * 4), d = new hl.Bytes(n * 4);
		for (i in 0...n) {
			a.setF32(i * 4, i * 0.25);
			b.setF32(i * 4, 1 + i * 0.5);
		}
		var reps = 20000;
		var simd = time("in-place SIMD add, 4096 floats  ", reps, () -> {
			var i = 0;
			while (i < n) {
				Vec.f32x4Add(d, i * 4, a, i * 4, b, i * 4);
				i += 4;
			}
		});
		var scalar = time("scalar add, 4096 floats         ", reps, () -> {
			for (i in 0...n) d.setF32(i * 4, a.getF32(i * 4) + b.getF32(i * 4));
		});
		Sys.println('add ratio simd/scalar: ${Math.round(simd / scalar * 100) / 100}');

		var simdF = time("in-place SIMD fma, 4096 floats  ", reps, () -> {
			var i = 0;
			while (i < n) {
				Vec.f32x4Fma(d, i * 4, a, i * 4, b, i * 4, d, i * 4);
				i += 4;
			}
		});
		var scalarF = time("scalar fma, 4096 floats         ", reps, () -> {
			for (i in 0...n) d.setF32(i * 4, a.getF32(i * 4) * b.getF32(i * 4) + d.getF32(i * 4));
		});
		Sys.println('fma ratio simd/scalar: ${Math.round(simdF / scalarF * 100) / 100}');
	}
}
