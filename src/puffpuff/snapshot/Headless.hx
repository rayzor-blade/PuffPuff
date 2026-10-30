package puffpuff.snapshot;

import gpu.GpuTextureViewDescriptor;
import haxe.io.Bytes;
import lime.app.Application;
import lime.ui.Window;
import puffpuff.gpu.WgpuContext;

/** Result of `Headless.render`: the PNG written and its RGBA8 pixels. **/
typedef HeadlessResult = {
	path:String,
	width:Int,
	height:Int,
	pixels:Bytes
}

/**
	Runs a `lime.app.Application` (so an OpenFL or Flixel scene) without a native window. Its windows render into one
	offscreen texture, and the result is written as a snapshot PNG. Use live windows only to test input.
**/
@:access(lime.app.Application)
@:access(lime.ui.Window)
class Headless {
	/**
		`setup` creates the application, its window (`width` x `height` in logical pixels, `scale` pixels per logical pixel)
		and the scene, with every window headless. Then `frames` updates and renders run.
	**/
	public static function render(name:String, width:Int, height:Int, setup:Void->Application, scale = 1.0, frames = 1):HeadlessResult {
		var offscreen = Snapshot.renderer();
		var pw = Std.int(Math.max(1, Math.round(width * scale)));
		var ph = Std.int(Math.max(1, Math.round(height * scale)));
		var texture = offscreen.createTexture(pw, ph);
		var view = texture.createView(new GpuTextureViewDescriptor());
		var target = WgpuContext.createOffscreen(view, pw, ph, offscreen.format);

		Window.__headless = target;
		Window.__headlessScale = scale;
		var app:Application;
		try {
			app = setup();
		} catch (e:Dynamic) {
			Window.__headless = null;
			view.destroy();
			texture.destroy();
			throw e;
		}
		Window.__headless = null;

		for (i in 0...frames) {
			if (i > 0) target.beginOffscreen(view, pw, ph);
			app.onUpdate.dispatch(16);
			for (window in app.__windows) window.__renderHeadlessFrame();
			target.endOffscreen();
		}

		var pixels = offscreen.readRgba8(texture, pw, ph);
		view.destroy();
		texture.destroy();

		sys.FileSystem.createDirectory(Snapshot.dir());
		var path = sys.FileSystem.absolutePath(haxe.io.Path.join([Snapshot.dir(), '$name.png']));
		sys.io.File.saveBytes(path, Png.encode(pw, ph, pixels));
		Snapshot.event('snapshot $name $path ${pw}x$ph');
		return {path: path, width: pw, height: ph, pixels: pixels};
	}
}
