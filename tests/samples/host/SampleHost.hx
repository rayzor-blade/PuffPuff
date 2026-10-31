import lime.utils.Assets;
import openfl.display.Application;
import openfl.display.DisplayObject;
import openfl.events.Event;
import puffpuff.snapshot.Headless;

/**
 * Runs an OpenFL sample's main `Sprite` on a headless window and checks that it drew something. run.sh sets the defines:
 * `sample_main` (the class), `sample_name`, `sample_size` (`WxH`), `sample_assets` (`dir:prefix`, `;` between several)
 * and optionally `sample_frames`.
 */
@:access(openfl.display.DisplayObject)
class SampleHost {
	static function main():Void {
		var name = haxe.macro.Compiler.getDefine("sample_name");
		var size = haxe.macro.Compiler.getDefine("sample_size").split("x");
		var assets = haxe.macro.Compiler.getDefine("sample_assets");
		var frames = Std.parseInt(haxe.macro.Compiler.getDefine("sample_frames"));
		var width = Std.parseInt(size[0]);
		var height = Std.parseInt(size[1]);

		if (assets != null && assets != "") {
			var library = new FolderLibrary();
			for (entry in assets.split(";")) {
				var at = entry.lastIndexOf(":");
				library.add(entry.substr(0, at), entry.substr(at + 1));
			}
			Assets.registerLibrary("default", library);
		}

		var result = Headless.render('sample-$name', width, height, () -> {
			var app = new Application();
			// Animations follow the wall clock, so each frame takes a moment.
			app.onUpdate.add(_ -> Sys.sleep(0.03));
			var window:openfl.display.Window = cast app.createWindow({width: width, height: height});
			// As OpenFL's application template does: the sample's constructor already sees its stage.
			DisplayObject.__initStage = window.stage;
			var root = SampleMacro.create();
			root.dispatchEvent(new Event(Event.ADDED_TO_STAGE, false, false));
			return app;
		}, 1.0, frames == null ? 40 : frames);

		var blankOk = haxe.macro.Compiler.getDefine("sample_blank_ok") != null;
		var colors = new Map<Int, Bool>();
		var i = 0;
		while (i < result.pixels.length && Lambda.count(colors) < 2) {
			colors.set((result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2), true);
			i += 4;
		}
		if (!blankOk && Lambda.count(colors) < 2) throw 'sample $name drew one flat color';
		Sys.println('sample $name ok ${result.path}');
		// A sample's timers would keep the process alive.
		Sys.exit(0);
	}
}
