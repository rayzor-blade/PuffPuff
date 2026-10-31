import openfl.display.Application;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * `BitmapData.draw` through `openfl.display.WgpuRenderer`, before any frame: shapes, a matrix, a color transform,
 * a clip rectangle, a blend mode, a bitmap drawn into a bitmap, and drawing twice into the same one. The results
 * show on the stage as bitmaps. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLDrawScene.hx
 */
class OpenFLDrawScene {
	static inline var W = 300;
	static inline var H = 130;
	static inline var BACKGROUND = 0x14181F;

	static function rect(color:Int, x:Float, y:Float, w:Float, h:Float, alpha = 1.0):Shape {
		var s = new Shape();
		s.graphics.beginFill(color, alpha);
		s.graphics.drawRect(x, y, w, h);
		s.graphics.endFill();
		return s;
	}

	static function place(data:BitmapData, x:Float, y:Float):Bitmap {
		var b = new Bitmap(data);
		b.x = x;
		b.y = y;
		return b;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;

		// Two shapes in a sprite, drawn as they are.
		var art = new Sprite();
		art.addChild(rect(0xCC3333, 0, 0, 40, 20));
		art.addChild(rect(0x3366FF, 0, 20, 40, 20));
		var plain = new BitmapData(40, 40, true, 0);
		plain.draw(art);
		stage.addChild(place(plain, 10, 10));

		// A matrix: scaled up and moved.
		var scaled = new BitmapData(40, 40, true, 0);
		scaled.draw(art, new Matrix(0.5, 0, 0, 0.5, 20, 20));
		stage.addChild(place(scaled, 60, 10));

		// A color transform: half alpha.
		var faded = new BitmapData(40, 40, true, 0);
		faded.draw(art, null, new ColorTransform(1, 1, 1, 0.5));
		stage.addChild(place(faded, 110, 10));

		// A clip rectangle: only the top half.
		var clipped = new BitmapData(40, 40, true, 0);
		clipped.draw(art, null, null, null, new Rectangle(0, 0, 40, 20));
		stage.addChild(place(clipped, 160, 10));

		// A blend mode: add over a dark red.
		var added = new BitmapData(40, 40, false, 0x330000);
		added.draw(rect(0x00FF00, 0, 0, 40, 40), null, null, BlendMode.ADD);
		stage.addChild(place(added, 210, 10));

		// A bitmap drawn into a bitmap, then more drawn on top without reading anything back.
		var stacked = new BitmapData(40, 40, true, 0);
		stacked.draw(plain);
		stacked.draw(rect(0xFFDD00, 10, 10, 20, 20));
		stage.addChild(place(stacked, 10, 70));

		// An opaque bitmap drawn into with a semi-transparent shape.
		var opaque = new BitmapData(40, 40, false, 0xFF0000);
		opaque.draw(rect(0x0000FF, 0, 0, 40, 40, 0.5));
		stage.addChild(place(opaque, 60, 70));

		// Reading the pixels back after drawing.
		var read = new BitmapData(40, 40, true, 0);
		read.draw(rect(0x00FF00, 0, 0, 20, 40));
		var left = read.getPixel(5, 5) == 0x00FF00;
		var right = read.getPixel32(30, 5) == 0;
		stage.addChild(rect(left && right ? 0x33CC66 : 0xFF00FF, 110, 70, 40, 40));
		return app;
	}

	static function main():Void {
		check("openfl-draw-scene", 1.0);
		check("openfl-draw-scene-2x", 2.0);
		Sys.println("OpenFL draw render ok");
	}

	static function check(name:String, scale:Float):Void {
		var result = Headless.render(name, W, H, build, scale);
		var failures = [];
		function at(x:Float, y:Float):Int {
			var i = (Std.int(y * scale) * result.width + Std.int(x * scale)) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		function expect(label:String, x:Float, y:Float, rgb:Int, tolerance = 6):Void {
			var got = at(x, y);
			if (Math.abs(((got >> 16) & 0xFF) - ((rgb >> 16) & 0xFF)) > tolerance || Math.abs(((got >> 8) & 0xFF) - ((rgb >> 8) & 0xFF)) > tolerance
				|| Math.abs((got & 0xFF) - (rgb & 0xFF)) > tolerance)
				failures.push('$label ${StringTools.hex(got, 6)} not ${StringTools.hex(rgb, 6)}');
		}

		expect("plain, red half", 30, 20, 0xCC3333);
		expect("plain, blue half", 30, 40, 0x3366FF);
		expect("scaled, red", 60 + 30, 10 + 25, 0xCC3333);
		expect("scaled, empty corner", 60 + 5, 10 + 5, BACKGROUND);
		expect("faded, red over background", 110 + 20, 10 + 10, 0x6B2B2F, 10);
		expect("clipped, top kept", 160 + 20, 10 + 10, 0xCC3333);
		expect("clipped, bottom cut", 160 + 20, 10 + 30, BACKGROUND);
		expect("blend add", 210 + 20, 10 + 20, 0x33FF00);
		expect("stacked, shape on top", 10 + 20, 70 + 20, 0xFFDD00);
		expect("stacked, bitmap below", 10 + 5, 70 + 5, 0xCC3333);
		expect("opaque, blended", 60 + 20, 70 + 20, 0x800080, 8);
		expect("pixels read back", 110 + 20, 70 + 20, 0x33CC66);

		if (failures.length > 0) throw 'OpenFL draw render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
