import openfl.Vector;
import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * `Graphics.beginBitmapFill` with `drawQuads` on a headless window through `openfl.display.WgpuRenderer`, at display
 * scales 1 and 2: quads at their own rectangles, placed by positions, scaled, rotated (which also checks the texture
 * coordinates' orientation) and drawn at half alpha. This is the path HaxeFlixel's sprite batching takes. Needs OpenFL
 * with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLQuadsScene.hx
 */
class OpenFLQuadsScene {
	static inline var W = 260;
	static inline var H = 240;
	static inline var BACKGROUND = 0x14181F;

	static function floats(values:Array<Float>):Vector<Float> {
		var v = new Vector<Float>();
		for (x in values) v.push(x);
		return v;
	}

	/** A 64 x 64 sheet of four 32 x 32 quadrants: red, green / blue, yellow. **/
	static function sheet():BitmapData {
		var bd = new BitmapData(64, 64, true, 0xFFFF0000);
		bd.fillRect(new Rectangle(32, 0, 32, 32), 0xFF00FF00);
		bd.fillRect(new Rectangle(0, 32, 32, 32), 0xFF0000FF);
		bd.fillRect(new Rectangle(32, 32, 32, 32), 0xFFFFFF00);
		return bd;
	}

	static function quads(bitmap:BitmapData, rects:Array<Float>, ?indices:Array<Int>, ?transforms:Array<Float>):Sprite {
		var s = new Sprite();
		s.graphics.beginBitmapFill(bitmap, null, false, false);
		var idx:Vector<Int> = null;
		if (indices != null) {
			idx = new Vector<Int>();
			for (i in indices) idx.push(i);
		}
		s.graphics.drawQuads(floats(rects), idx, transforms == null ? null : floats(transforms));
		s.graphics.endFill();
		return s;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;
		var bitmap = sheet();
		var four = [0, 0, 32, 32, 32, 0, 32, 32, 0, 32, 32, 32, 32, 32, 32, 32.0];

		// No transforms: each quad is drawn at its own rectangle, so this is the sheet itself.
		var plain = quads(bitmap, four);
		plain.x = 10;
		plain.y = 10;
		stage.addChild(plain);

		// Positions: red, yellow, green in a row with gaps.
		var row = quads(bitmap, four, [0, 3, 1], [0, 0, 40, 0, 80, 0]);
		row.x = 100;
		row.y = 10;
		stage.addChild(row);

		// A full matrix: the red quad doubled, and the green one turned a quarter.
		stage.addChild(quads(bitmap, four, [0, 1], [2, 0, 0, 2, 10, 100, 0, 1, -1, 0, 160, 100]));

		// The whole sheet turned a quarter: red goes to the top right.
		stage.addChild(quads(bitmap, [0, 0, 64, 64.0], null, [0, 1, -1, 0, 240, 100]));

		// Half alpha over white.
		var white = new Shape();
		white.graphics.beginFill(0xFFFFFF);
		white.graphics.drawRect(10, 180, 40, 40);
		white.graphics.endFill();
		stage.addChild(white);
		var half = quads(bitmap, [0, 0, 32, 32.0]);
		half.x = 14;
		half.y = 184;
		half.alpha = 0.5;
		stage.addChild(half);

		return app;
	}

	static function main():Void {
		check("openfl-quads-scene-1x", 1.0);
		check("openfl-quads-scene", 2.0);
		Sys.println("OpenFL quads render ok");
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
		var red = 0xFF0000, green = 0x00FF00, blue = 0x0000FF, yellow = 0xFFFF00;

		expect("sheet red", 10 + 16, 10 + 16, red);
		expect("sheet green", 10 + 48, 10 + 16, green);
		expect("sheet blue", 10 + 16, 10 + 48, blue);
		expect("sheet yellow", 10 + 48, 10 + 48, yellow);

		expect("row red", 100 + 16, 10 + 16, red);
		expect("row gap", 100 + 36, 10 + 16, BACKGROUND);
		expect("row yellow", 100 + 40 + 16, 10 + 16, yellow);
		expect("row green", 100 + 80 + 16, 10 + 16, green);

		expect("doubled red", 10 + 32, 100 + 32, red);
		expect("doubled red edge", 10 + 70, 100 + 32, BACKGROUND);
		expect("turned green", 144, 116, green);
		expect("left of the turned green", 120, 116, BACKGROUND);

		expect("turned sheet: red top right", 240 - 10, 100 + 10, red);
		expect("turned sheet: green bottom right", 240 - 10, 100 + 50, green);
		expect("turned sheet: blue top left", 240 - 50, 100 + 10, blue);
		expect("turned sheet: yellow bottom left", 240 - 50, 100 + 50, yellow);

		expect("half alpha over white", 14 + 16, 184 + 16, 0xFF8080, 6);
		expect("white around it", 12, 182, 0xFFFFFF);

		if (failures.length > 0) throw 'OpenFL quads render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
