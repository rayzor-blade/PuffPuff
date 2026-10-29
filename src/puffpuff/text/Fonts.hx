package puffpuff.text;

import haxe.io.Bytes;

/**
 * Manages font registration in `blinc_abi`'s shared font database, including automatic
 * registration of bundled default faces (`Arimo.woff2` and `Arimo-Italic.woff2`).
 */
class Fonts {
	static var bundledRegistered = false;

	/**
	 * Registers TTF, OpenType, collection, or WOFF2 bytes into the font engine.
	 * Returns the number of faces registered.
	 */
	public static function register(bytes:Bytes):Int {
		ensureBundled();
		if (bytes == null || bytes.length == 0) return 0;
		#if hl
		return TextNative.blinc_font_register(bytes.getData(), bytes.length);
		#else
		return 0;
		#end
	}

	public static function ensureBundled():Void {
		if (bundledRegistered) return;
		bundledRegistered = true;
		#if hl
		for (name in haxe.Resource.listNames()) {
			if (StringTools.startsWith(name, "puffpuff.font.")) {
				var bytes = haxe.Resource.getBytes(name);
				if (bytes != null && bytes.length > 0) {
					TextNative.blinc_font_register(bytes.getData(), bytes.length);
				}
			}
		}
		#end
	}
}
