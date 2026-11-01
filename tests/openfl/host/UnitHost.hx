import openfl.display.Application;
import puffpuff.snapshot.Headless;

/**
 * Runs an area's `Tests.main` inside a running OpenFL application on a headless window, for tests that need a stage, frames or
 * `Lib.application`: sockets deliver data on ENTER_FRAME, NativeWindow opens windows through the application. Ends when
 * utest has printed its summary.
 */
@:access(lime.app.Application)
@:access(lime.ui.Window)
class UnitHost {
	static function main():Void {
		var started = false;
		var done = false;
		var print = haxe.Log.trace;
		haxe.Log.trace = (v:Dynamic, ?pos:haxe.PosInfos) -> {
			print(v, pos);
			if (Std.string(v).indexOf("assertations:") >= 0) done = true;
		};
		var frames = 0;
		Headless.render("unit-host", 320, 240, () -> {
			var app = new Application();
			app.createWindow({width: 320, height: 240});
			app.onUpdate.add(_ -> {
				// Windows the tests open take their events (focus, close requests) from here.
				for (window in app.__windows.copy()) window.__pollEvents();
				if (!started) {
					started = true;
					Tests.main();
				} else if (done) {
					Sys.stdout().flush();
					Sys.exit(0);
				}
			});
			return app;
		}, 1.0, 100000);
	}
}
