package puffpuff.snapshot;

import lime.app.Application;
import lime.graphics.RenderContext;

/**
 * Renders a PuffPuff / Lime / OpenFL scene offscreen to a PNG (or opens a live window when `PUFFPUFF_WINDOW=1`).
 *
 * Each snapshot is written to `dir()` (`$PUFFPUFF_SNAPSHOT_DIR` or `.puffpuff/snapshots`) as `<name>.png`
 * and logged to `dir()/events.log`:
 *
 *   snapshot <name> <absolute path> <width>x<height>
 *   error <name> <message>
 */
class Snapshot {
	static var offscreen:Null<Offscreen>;

	/** Where snapshots go: `$PUFFPUFF_SNAPSHOT_DIR`, or `.puffpuff/snapshots` under the working directory. **/
	public static function dir():String {
		var d = Sys.getEnv("PUFFPUFF_SNAPSHOT_DIR");
		return d != null && d != "" ? d : ".puffpuff/snapshots";
	}

	/** Whether scenes open in a live interactive window (`PUFFPUFF_WINDOW=1`). **/
	public static function windowWanted():Bool {
		var w = Sys.getEnv("PUFFPUFF_WINDOW");
		return w != null && w != "" && w != "0";
	}

	/**
	 * Renders a single-frame scene `draw(context)` at `width` x `height` (scaled by `scale`) to `<dir>/<name>.png`,
	 * or opens a live window when `PUFFPUFF_WINDOW=1`.
	 */
	public static function scene(
		name:String,
		width:Int,
		height:Int,
		draw:RenderContext->Void,
		clear:Int = 0x1A1A2E,
		clearAlpha:Float = 1.0,
		scale:Float = 1.0
	):String {
		if (windowWanted()) {
			openWindow(name, width, height, (dt, ctx) -> draw(ctx), clear);
			return "";
		}
		try {
			return capture(name, draw, width, height, clear, clearAlpha, scale);
		} catch (e:haxe.Exception) {
			event('error $name ${e.message.split("\n").join(" ")}');
			Sys.println(e.details());
			throw e;
		}
	}

	/**
	 * Renders a multi-frame animated sequence as `<name>-000.png` .. `<name>-NNN.png` at fixed `fps`,
	 * or runs in a live window when `PUFFPUFF_WINDOW=1`.
	 */
	public static function sequence(
		name:String,
		width:Int,
		height:Int,
		step:(frame:Int, dt:Float, context:RenderContext)->Void,
		fps:Int = 30,
		frames:Int = 30,
		clear:Int = 0x1A1A2E,
		clearAlpha:Float = 1.0,
		scale:Float = 1.0
	):Array<String> {
		if (windowWanted()) {
			var frameIdx = 0;
			openWindow(name, width, height, (dt, ctx) -> {
				step(frameIdx++, dt, ctx);
			}, clear);
			return [];
		}
		try {
			var paths:Array<String> = [];
			var dt = 1.0 / fps;
			for (i in 0...frames) {
				var frameName = '$name-${StringTools.lpad(Std.string(i), "0", 3)}';
				paths.push(capture(frameName, ctx -> step(i, dt, ctx), width, height, clear, clearAlpha, scale));
			}
			return paths;
		} catch (e:haxe.Exception) {
			event('error $name ${e.message.split("\n").join(" ")}');
			Sys.println(e.details());
			throw e;
		}
	}

	/**
	 * Captures `draw(context)` offscreen into `<dir>/<name>.png` and logs the event to `events.log`.
	 */
	public static function capture(
		name:String,
		draw:RenderContext->Void,
		width:Int,
		height:Int,
		clear:Int = 0x1A1A2E,
		clearAlpha:Float = 1.0,
		scale:Float = 1.0
	):String {
		if (offscreen == null) {
			offscreen = Offscreen.create();
		}
		offscreen.clear = clear;
		offscreen.clearAlpha = clearAlpha;
		offscreen.scale = scale;

		var pixelWidth = Std.int(Math.max(1, Math.round(width * scale)));
		var pixelHeight = Std.int(Math.max(1, Math.round(height * scale)));
		var pixels = offscreen.renderToRgba8(draw, width, height);

		sys.FileSystem.createDirectory(dir());
		var path = sys.FileSystem.absolutePath(haxe.io.Path.join([dir(), '$name.png']));
		sys.io.File.saveBytes(path, Png.encode(pixelWidth, pixelHeight, pixels));
		event('snapshot $name $path ${pixelWidth}x$pixelHeight');
		return path;
	}

	/** Returns the shared `Offscreen` instance. **/
	public static function renderer():Offscreen {
		if (offscreen == null) {
			offscreen = Offscreen.create();
		}
		return offscreen;
	}

	/** Appends `line` to `events.log` in the snapshot directory. **/
	public static function event(line:String):Void {
		sys.FileSystem.createDirectory(dir());
		var out = sys.io.File.append(haxe.io.Path.join([dir(), "events.log"]), false);
		out.writeString(line + "\n");
		out.close();
	}

	private static function openWindow(
		name:String,
		width:Int,
		height:Int,
		onFrame:(dt:Float, ctx:RenderContext)->Void,
		clear:Int
	):Void {
		var app = new Application();
		var lastDt:Float = 1.0 / 60.0;
		app.create({
			windows: [{
				title: name,
				width: width,
				height: height,
				background: clear,
				vsync: true
			}]
		});
		app.onUpdate.add(deltaMs -> {
			lastDt = deltaMs / 1000.0;
		});
		app.window.onRender.add(ctx -> {
			onFrame(lastDt, ctx);
		});
		var maxFrames:Int = -1;
		var envFrames = Sys.getEnv("PUFFPUFF_WINDOW_FRAMES");
		if (envFrames != null) {
			var parsed = Std.parseInt(envFrames);
			if (parsed != null && parsed > 0) maxFrames = parsed;
		}
		app.exec(maxFrames);
	}
}

