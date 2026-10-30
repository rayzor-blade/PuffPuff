import haxe.Json;

/** One measured operation. `run` is one iteration, and `ops` is how many logical operations it does. **/
typedef BenchCase = {
	name:String,
	run:Void->Void,
	?ops:Int,
	?setup:Void->Void,
	/** `null` if the output is correct, otherwise what's wrong. **/
	?check:Void->Null<String>,
	/** Digest of the output. A digest that differs from the baseline gets reported for review. **/
	?checksum:Void->String,
	/** Fails the case if it allocates more than this many bytes per operation. **/
	?maxAllocPerOp:Float,
	/** Minimum length of one timing sample, in milliseconds. **/
	?sampleMs:Float
}

typedef BenchResult = {
	name:String,
	ops:Int,
	?minNs:Float,
	?medianNs:Float,
	?p95Ns:Float,
	?samples:Int,
	?allocBytesPerOp:Float,
	/** Live memory growth across a third batch of runs, after a full GC. A leak signal, page-granular. **/
	?leakBytes:Float,
	?checksum:String,
	?error:String
}

/**
	Runs cases in two passes, each in its own process. `time` is best-of-N nanoseconds per operation. `alloc` is bytes
	allocated per operation (exact only with ASH_GC_TLAB=0) plus memory growth across a third batch.
**/
class Harness {
	static inline var SAMPLES = 15;

	public static function runCase(c:BenchCase, pass:String):BenchResult {
		var ops = c.ops != null ? c.ops : 1;
		var result:BenchResult = {name: c.name, ops: ops};
		try {
			if (c.setup != null) c.setup();
			c.run();
			if (c.check != null) {
				var problem = c.check();
				if (problem != null) result.error = problem;
			}
			if (c.checksum != null) result.checksum = c.checksum();
			if (pass == "time") time(c, ops, result) else alloc(c, ops, result);
		} catch (e:haxe.Exception) {
			result.error = 'exception: ${e.message}';
		}
		return result;
	}

	/** Iterations per sample so that one sample lasts at least `sampleMs`. **/
	static function calibrate(c:BenchCase):Int {
		var target = (c.sampleMs != null ? c.sampleMs : 25.0) / 1000.0;
		var iters = 1;
		while (iters < (1 << 24)) {
			var t0 = haxe.Timer.stamp();
			for (i in 0...iters) c.run();
			var dt = haxe.Timer.stamp() - t0;
			if (dt >= target) break;
			iters = dt <= 0 ? iters * 16 : Std.int(Math.max(iters + 1, Math.min(iters * 16, iters * target / dt * 1.2)));
		}
		return iters;
	}

	static function time(c:BenchCase, ops:Int, r:BenchResult):Void {
		for (i in 0...3) c.run();
		var iters = calibrate(c);
		var samples:Array<Float> = [];
		for (s in 0...SAMPLES) {
			var t0 = haxe.Timer.stamp();
			for (i in 0...iters) c.run();
			samples.push((haxe.Timer.stamp() - t0) / (iters * ops) * 1e9);
		}
		samples.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
		r.samples = SAMPLES;
		r.minNs = samples[0];
		r.medianNs = samples[SAMPLES >> 1];
		r.p95Ns = samples[Std.int(Math.min(SAMPLES - 1, Math.ceil(SAMPLES * 0.95) - 1))];
	}

	static function alloc(c:BenchCase, ops:Int, r:BenchResult):Void {
		for (i in 0...3) c.run();
		var forced = Sys.getEnv("BENCH_ALLOC_RUNS");
		var runs = forced != null ? Std.parseInt(forced) : Std.int(Math.min(calibrate(c), 20000));
		// What reading the counter allocates, so it isn't charged to the case.
		var o0 = hl.Gc.stats();
		var o1 = hl.Gc.stats();
		var overhead = o1.totalAllocated - o0.totalAllocated;
		hl.Gc.major();
		var before = hl.Gc.stats();
		for (i in 0...runs) c.run();
		var after = hl.Gc.stats();
		r.allocBytesPerOp = Math.max(0, after.totalAllocated - before.totalAllocated - overhead) / (runs * ops);
		hl.Gc.major();
		// Two warm batches absorb one-time heap growth. A leak is whatever a third batch still adds.
		for (i in 0...runs) c.run();
		hl.Gc.major();
		var settled = hl.Gc.stats();
		for (i in 0...runs) c.run();
		hl.Gc.major();
		var third = hl.Gc.stats();
		r.leakBytes = third.currentMemory - settled.currentMemory;
		if (c.maxAllocPerOp != null && r.allocBytesPerOp > c.maxAllocPerOp + 0.01)
			r.error = 'allocates ${Math.round(r.allocBytesPerOp * 10) / 10} B/op, limit ${c.maxAllocPerOp}';
	}

	public static function table(results:Array<BenchResult>):String {
		var b = new StringBuf();
		b.add(StringTools.rpad("case", " ", 38) + StringTools.lpad("min ns/op", " ", 12) + StringTools.lpad("median", " ", 12) + StringTools.lpad("p95", " ", 12)
			+ StringTools.lpad("alloc B/op", " ", 12) + StringTools.lpad("leak B", " ", 12) + "  status\n");
		for (r in results) {
			b.add(StringTools.rpad(r.name, " ", 38));
			b.add(StringTools.lpad(num(r.minNs), " ", 12) + StringTools.lpad(num(r.medianNs), " ", 12) + StringTools.lpad(num(r.p95Ns), " ", 12));
			b.add(StringTools.lpad(num(r.allocBytesPerOp), " ", 12) + StringTools.lpad(num(r.leakBytes), " ", 12));
			b.add("  " + (r.error == null ? "ok" : "FAIL: " + r.error) + "\n");
		}
		return b.toString();
	}

	static function num(v:Null<Float>):String {
		if (v == null) return "-";
		return Std.string(Math.round(v * 10) / 10);
	}

	public static function toJson(results:Array<BenchResult>, meta:Dynamic):String {
		return Json.stringify({meta: meta, results: results}, null, "  ");
	}

	/** FNV-1a over a byte range, as eight hex digits. **/
	public static function fnv(bytes:haxe.io.Bytes, start:Int, length:Int):String {
		var h = 0x811C9DC5;
		for (i in start...start + length) {
			h ^= bytes.get(i);
			h = h * 0x01000193;
		}
		return StringTools.hex(h, 8);
	}
}
