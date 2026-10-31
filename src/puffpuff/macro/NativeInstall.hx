package puffpuff.macro;

#if macro
import haxe.Json;
import haxe.io.Path;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

/**
 * Finds the `blinc_abi.hdll` that a release package bundles for this host, listed in `native/hdlls.json`.
 * A repository checkout has none, and `DefaultFonts` falls back to sibling builds.
 */
class NativeInstall {
	/** The library's root, where `native/hdlls.json` is. **/
	public static function root():String {
		var module = Context.resolvePath("puffpuff/macro/NativeInstall.hx");
		return Path.directory(Path.directory(Path.directory(Path.directory(FileSystem.fullPath(module)))));
	}

	/** The bundled library for this host, or null when the package has none. **/
	public static function blincAbi():Null<String> {
		var manifest = Path.join([root(), "native/hdlls.json"]);
		if (!FileSystem.exists(manifest))
			return null;
		var platforms:Dynamic = Json.parse(File.getContent(manifest)).platforms;
		var entry:Dynamic = platforms == null ? null : Reflect.field(platforms, hostPlatform());
		if (entry == null)
			return null;
		var path = Path.join([root(), entry.packagePath]);
		return FileSystem.exists(path) ? path : null;
	}

	/** The manifest's name for this host, such as `macos-aarch64`. **/
	public static function hostPlatform():String {
		var os = switch (Sys.systemName()) {
			case "Linux": "linux";
			case "Mac": "macos";
			case "Windows": "windows";
			case other: other.toLowerCase();
		};
		var arch:String;
		if (os == "windows") {
			arch = Sys.getEnv("PROCESSOR_ARCHITEW6432");
			if (arch == null)
				arch = Sys.getEnv("PROCESSOR_ARCHITECTURE");
		} else {
			var process = new Process("uname", ["-m"]);
			arch = StringTools.trim(process.stdout.readAll().toString());
			var status = process.exitCode();
			process.close();
			if (status != 0)
				throw "puffpuff could not detect the CPU architecture";
		}
		arch = switch (arch == null ? "" : arch.toLowerCase()) {
			case "amd64", "x86_64": "x86_64";
			case "arm64", "aarch64": "aarch64";
			case other: other;
		};
		return '$os-$arch';
	}
}
#end
