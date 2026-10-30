import openfl.display.Application;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * OpenFL `Bitmap`s and `BitmapData` on a headless window through `openfl.display.WgpuRenderer`, at display
 * scales 1 and 2: nearest and smoothed scaling, alpha, per-pixel alpha, rotation, and display order
 * against vector shapes. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLBitmapScene.hx
 */
class OpenFLBitmapScene {
	static inline var W = 480;
	static inline var H = 200;
	static inline var BACKGROUND = 0x14181F;

	/** Four 16 x 16 quadrants: red, green / blue, white. **/
	static function quadrants():BitmapData {
		var bd = new BitmapData(32, 32, false, 0xFFFF0000);
		bd.fillRect(new Rectangle(16, 0, 16, 16), 0xFF00FF00);
		bd.fillRect(new Rectangle(0, 16, 16, 16), 0xFF0000FF);
		bd.fillRect(new Rectangle(16, 16, 16, 16), 0xFFFFFFFF);
		return bd;
	}

	static function place(bitmap:Bitmap, x:Float, y:Float, scale = 1.0):Bitmap {
		bitmap.x = x;
		bitmap.y = y;
		bitmap.scaleX = bitmap.scaleY = scale;
		return bitmap;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;
		var pixels = quadrants();

		// 1:1, then four times larger without and with smoothing.
		stage.addChild(place(new Bitmap(pixels), 10, 10));
		stage.addChild(place(new Bitmap(pixels, null, false), 60, 10, 4));
		stage.addChild(place(new Bitmap(pixels, null, true), 200, 10, 4));

		// Half transparent, over a vector rectangle.
		var under = new Shape();
		under.graphics.beginFill(0xFFFFFF);
		under.graphics.drawRect(340, 10, 60, 60);
		under.graphics.endFill();
		stage.addChild(under);
		var faded = place(new Bitmap(pixels), 350, 20);
		faded.alpha = 0.5;
		stage.addChild(faded);

		// Per-pixel alpha: a half transparent red square on a transparent bitmap.
		var ghost = new BitmapData(32, 32, true, 0x00000000);
		ghost.fillRect(new Rectangle(8, 8, 16, 16), 0x80FF0000);
		stage.addChild(place(new Bitmap(ghost), 420, 20));

		// Order: vector, bitmap, vector.
		var low = new Shape();
		low.graphics.beginFill(0x00AA00);
		low.graphics.drawRect(10, 120, 60, 60);
		low.graphics.endFill();
		stage.addChild(low);
		var purple = new BitmapData(40, 40, false, 0xFF8844CC);
		stage.addChild(place(new Bitmap(purple), 30, 140));
		var high = new Shape();
		high.graphics.beginFill(0xFFDD00);
		high.graphics.drawRect(50, 160, 40, 40);
		high.graphics.endFill();
		stage.addChild(high);

		// Rotated a quarter turn about its top left corner.
		var turned = place(new Bitmap(pixels), 200, 120);
		turned.rotation = 90;
		stage.addChild(turned);

		return app;
	}

	static function main():Void {
		check("openfl-bitmap-scene-1x", 1.0);
		check("openfl-bitmap-scene", 2.0);
		Sys.println("OpenFL bitmap render ok");
	}

	static function check(name:String, scale:Float):Void {
		var result = Headless.render(name, W, H, build, scale);
		var failures = [];
		function at(x:Float, y:Float):Int {
			var i = (Std.int(y * scale) * result.width + Std.int(x * scale)) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		function expect(label:String, x:Float, y:Float, rgb:Int, tolerance = 4):Void {
			var got = at(x, y);
			if (Math.abs(((got >> 16) & 0xFF) - ((rgb >> 16) & 0xFF)) > tolerance || Math.abs(((got >> 8) & 0xFF) - ((rgb >> 8) & 0xFF)) > tolerance
				|| Math.abs((got & 0xFF) - (rgb & 0xFF)) > tolerance)
				failures.push('$label ${StringTools.hex(got, 6)} not ${StringTools.hex(rgb, 6)}');
		}

		expect("1:1 red", 18, 18, 0xFF0000);
		expect("1:1 green", 34, 18, 0x00FF00);
		expect("1:1 blue", 18, 34, 0x0000FF);
		expect("1:1 white", 34, 34, 0xFFFFFF);
		expect("background", 5, 5, BACKGROUND);

		// Nearest: the edge between red and green (x = 60 + 64) is sharp.
		expect("nearest left of edge", 60 + 62, 30, 0xFF0000);
		expect("nearest right of edge", 60 + 66, 30, 0x00FF00);
		// Smoothed: at the edge the two colors are mixed about evenly.
		var edge = at(200 + 64, 30);
		if (((edge >> 16) & 0xFF) < 90 || ((edge >> 16) & 0xFF) > 170 || ((edge >> 8) & 0xFF) < 90 || ((edge >> 8) & 0xFF) > 170)
			failures.push('smoothed edge ${StringTools.hex(edge, 6)} not a mix');

		// Alpha 0.5 of blue over white.
		expect("half alpha over white", 360, 40, 0x8080FF, 6);
		// Half transparent red over the background: (255 + 20) / 2 for red.
		expect("per-pixel alpha", 420 + 16, 20 + 16, 0x8A0C0F, 8);
		expect("fully transparent part", 420 + 2, 20 + 2, BACKGROUND);

		// Order.
		expect("vector under bitmap", 15, 125, 0x00AA00);
		expect("bitmap over vector", 35, 145, 0x8844CC);
		expect("vector over bitmap", 60, 170, 0xFFDD00);

		// Rotation by 90 degrees about the top left corner: x' = x - v, y' = y + u.
		expect("rotated red", 200 - 8, 120 + 8, 0xFF0000);
		expect("rotated green", 200 - 8, 120 + 24, 0x00FF00);
		expect("rotated blue", 200 - 24, 120 + 8, 0x0000FF);
		expect("rotated white", 200 - 24, 120 + 24, 0xFFFFFF);

		if (failures.length > 0) throw 'OpenFL bitmap render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
