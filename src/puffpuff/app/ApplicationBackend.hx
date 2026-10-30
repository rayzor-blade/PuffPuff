package puffpuff.app;

import haxe.Timer;
import lime.app.Application;
import lime.app.FrameOptions;
import lime.app.FrameProfile;
import lime.app.VSyncMode;
import lime.system.Orientation;

/** Main loop for `lime.app.Application` on hlwindow and hlwgpu. **/
@:access(lime.app.Application)
@:access(lime.ui.Window)
class ApplicationBackend {
	/** When positive, `exec` closes every window and returns after this many frames (automated runs). **/
	public static var maxFrames:Int = -1;

	final parent:Application;
	var frameProfile:FrameProfile = Balanced;
	var frameOptions:FrameOptions = {};
	var vsyncMode:VSyncMode = Off;
	var exiting = false;

	public function new(parent:Application) {
		this.parent = parent;
	}

	public function configureFrameTiming(profile:FrameProfile, frameRate:Float, options:FrameOptions):Void {
		frameProfile = profile;
		frameOptions = options;
	}

	public function setVSyncMode(mode:VSyncMode):Void {
		vsyncMode = mode;
	}

	public function getDeviceOrientation():Orientation {
		return UNKNOWN;
	}

	public function exit():Void {
		exiting = true;
	}

	public function exec():Int {
		var limit = maxFrames;
		var env = Sys.getEnv("PUFFPUFF_WINDOW_FRAMES");
		if (limit <= 0 && env != null) {
			var parsed = Std.parseInt(env);
			if (parsed != null && parsed > 0) limit = parsed;
		}

		var lastTime = Timer.stamp();
		var frameCount = 0;

		while (parent.__windows.length > 0 && !exiting) {
			for (win in parent.__windows.copy()) {
				if (!win.__pollEvents()) parent.__removeWindow(win);
			}
			if (parent.__windows.length == 0) break;

			lime.ui.Gamepad.__poll();

			var now = Timer.stamp();
			var deltaMs = Std.int(Math.max(1, Math.round((now - lastTime) * 1000.0)));
			lastTime = now;

			parent.onUpdate.dispatch(deltaMs);

			for (win in parent.__windows) win.__renderFrame();

			frameCount++;
			if (limit > 0 && frameCount >= limit) {
				for (win in parent.__windows.copy()) win.close();
				break;
			}

			var targetFps = parent.__getFrameRate();
			if (targetFps > 0) {
				var elapsed = Timer.stamp() - now;
				var targetFrameTime = 1.0 / targetFps;
				if (elapsed < targetFrameTime) Sys.sleep(targetFrameTime - elapsed);
			}
		}

		parent.onExit.dispatch(0);
		return 0;
	}
}
