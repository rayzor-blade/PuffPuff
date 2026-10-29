package puffpuff.macro;

#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;

/**
 * Bundles the default variable Arimo faces as Haxe resources and stages `blinc_abi.hdll`
 * next to the compiled HashLink `.hl` output.
 */
class DefaultFonts {
	static final FONTS = ["Arimo.woff2", "Arimo-Italic.woff2"];

	public static function use():Void {
		var here = Context.resolvePath("puffpuff/macro/DefaultFonts.hx");
		var root = Path.directory(Path.directory(Path.directory(Path.directory(here))));

		if (!Context.defined("puffpuff_no_default_font")) {
			for (name in FONTS) {
				var file = Path.join([root, "fonts", name]);
				if (FileSystem.exists(file)) {
					Context.addResource('puffpuff.font.$name', File.getBytes(file));
				}
			}
		}

		var out = Compiler.getOutput();
		if (Path.extension(out) == "hl") {
			var outDir = Path.directory(out);
			if (outDir == "") outDir = ".";
			Context.onAfterGenerate(function() {
				stageBlincAbi(root, outDir);
			});
		}
	}

	static function stageBlincAbi(root:String, outDir:String):Void {
		var dest = Path.join([outDir, "blinc_abi.hdll"]);
		var envDir = Sys.getEnv("PUFFPUFF_NATIVE_DIR");
		var candidates = [];
		if (envDir != null && envDir != "") {
			candidates.push(Path.join([envDir, "blinc_abi.hdll"]));
			candidates.push(Path.join([envDir, "libblinc_abi.dylib"]));
		}
		candidates.push(Path.join([root, "..", "blinc_abi", "target", "debug", "libblinc_abi.dylib"]));
		candidates.push(Path.join([root, "..", "blinc_abi", "target", "release", "libblinc_abi.dylib"]));
		candidates.push(Path.join([root, "..", "ashui", "tools", "snapshot", "bin", "blinc_abi.hdll"]));

		for (src in candidates) {
			if (FileSystem.exists(src)) {
				if (!FileSystem.exists(outDir)) {
					FileSystem.createDirectory(outDir);
				}
				File.copy(src, dest);
				return;
			}
		}
	}
}
#end
