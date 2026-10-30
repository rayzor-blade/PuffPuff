import Harness.BenchResult;

/**
	Runs the benchmark cases in one pass and writes the results as JSON.

	    Suite <time|alloc> <out.json> [name-prefix[,name-prefix...]]

	BENCH_MACHINE, BENCH_MODE and BENCH_COMMIT are copied into the file's `meta`.
**/
class Suite {
	static function main():Void {
		var args = Sys.args();
		if (args.length < 2 || (args[0] != "time" && args[0] != "alloc")) {
			Sys.println("usage: Suite <time|alloc> <out.json> [name-prefix]");
			Sys.exit(2);
		}
		var pass = args[0], out = args[1], prefix = args.length > 2 ? args[2] : "";
		var prefixes = prefix.split(",");
		var results:Array<BenchResult> = [];
		for (c in Cases.all()) {
			if (prefix != "" && !Lambda.exists(prefixes, p -> StringTools.startsWith(c.name, p))) continue;
			Sys.println('  ${c.name} ...');
			results.push(Harness.runCase(c, pass));
		}
		Sys.print(Harness.table(results));
		var env = name -> {
			var v = Sys.getEnv(name);
			v != null ? v : "";
		};
		sys.io.File.saveContent(out, Harness.toJson(results, {
			pass: pass,
			machine: env("BENCH_MACHINE"),
			mode: env("BENCH_MODE"),
			commit: env("BENCH_COMMIT"),
			cpu: env("BENCH_CPU"),
			ash: env("BENCH_ASH")
		}));
		var failed = results.filter(r -> r.error != null).length;
		if (failed > 0) {
			Sys.println('$failed case(s) failed');
			Sys.exit(1);
		}
	}
}
