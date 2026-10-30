package puffpuff.macro;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;

/**
 * Defines the platform flags Lime's tool sets for a desktop build (`mac` and `macos`, `windows`, `linux`, `desktop`) for
 * the host, which is also where the program runs. OpenFL reads them, for instance to find the system fonts. Flags that
 * are already set stay as they are.
 */
class PlatformDefines {
	public static function use():Void {
		var flags = switch (Sys.systemName()) {
			case "Mac": ["mac", "macos"];
			case "Windows": ["windows"];
			case "Linux": ["linux"];
			default: [];
		}
		if (flags.length > 0) flags.push("desktop");
		for (flag in flags) {
			if (!Context.defined(flag)) Compiler.define(flag);
		}
	}
}
#end
