import lime.graphics.Image;
import puffpuff.text.FontAtlas;
import puffpuff.text.Fonts;
import puffpuff.text.GlyphOutlines;

/**
 * Binds every blinc_abi native PuffPuff calls. HashLink checks each one's signature when it loads the
 * bytecode, and records a native only where compiled code refers to it, so these are the classes that call
 * blinc_abi. Loading this program is the test; nothing here needs a GPU.
 */
class Main {
	static function main():Void {
		var callers:Array<Class<Dynamic>> = [Fonts, FontAtlas, GlyphOutlines, Image];
		Sys.println(callers.length == 4 ? "all natives bound" : "missing callers");
	}
}
