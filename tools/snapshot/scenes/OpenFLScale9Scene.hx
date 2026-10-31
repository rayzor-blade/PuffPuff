import openfl.display.Application;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * OpenFL `scale9Grid` through `openfl.display.WgpuRenderer`: a rounded button with a 4 pixel outline, stretched to several
 * sizes. With a grid the corners and the outline keep their size and only the middle stretches; without one the shape
 * and its outline grow together, for comparison. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLScale9Scene.hx
 */
class OpenFLScale9Scene {
	static inline var W = 420;
	static inline var H = 220;
	static inline var BACKGROUND = 0x14181F;
	static inline var FILL = 0x3366CC;
	static inline var OUTLINE = 0xFFCC33;

	/** A 60 x 30 rounded button whose outline lies inside the bounds, so the grid's corners are 12 pixels. **/
	static function button(grid:Bool, x:Float, y:Float, sx:Float, sy:Float):Sprite {
		var s = new Sprite();
		s.graphics.lineStyle(4, OUTLINE);
		s.graphics.beginFill(FILL);
		s.graphics.drawRoundRect(2, 2, 56, 26, 16, 16);
		s.graphics.endFill();
		if (grid) s.scale9Grid = new Rectangle(12, 12, 36, 6);
		s.x = x;
		s.y = y;
		s.scaleX = sx;
		s.scaleY = sy;
		return s;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;
		stage.addChild(button(true, 10, 10, 1, 1));
		stage.addChild(button(true, 10, 60, 3, 1));
		stage.addChild(button(true, 10, 110, 2, 3));
		stage.addChild(button(false, 230, 60, 3, 1));
		stage.addChild(button(false, 230, 110, 2, 3));

		// A circle through the grid, and a shape that ends up smaller than its corners.
		var disc = new Sprite();
		disc.graphics.beginFill(0xCC3366);
		disc.graphics.drawCircle(20, 20, 20);
		disc.graphics.endFill();
		disc.scale9Grid = new Rectangle(14, 14, 12, 12);
		disc.x = 230;
		disc.y = 10;
		disc.scaleX = 2;
		stage.addChild(disc);
		return app;
	}

	static function main():Void {
		var result = Headless.render("openfl-scale9-scene", W, H, build, 1.0, 3);
		var failures = [];
		function at(x:Int, y:Int):Int {
			var i = (y * W + x) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		function expect(name:String, x:Int, y:Int, color:Int):Void {
			var got = at(x, y);
			if (got != color) failures.push('$name (${x},${y}) is ${StringTools.hex(got, 6)}, expected ${StringTools.hex(color, 6)}');
		}
		// Stretched to 180 wide, the grid's outline is still 4 pixels at each end and the middle is fill.
		expect("grid wide, left outline", 12, 75, OUTLINE);
		expect("grid wide, inside outline", 16, 75, FILL);
		expect("grid wide, middle", 100, 75, FILL);
		expect("grid wide, right outline", 10 + 180 - 3, 75, OUTLINE);
		expect("grid wide, top outline", 100, 62, OUTLINE);
		expect("grid wide, below top outline", 100, 67, FILL);
		// Stretched taller by 3, the grid keeps the top outline at 4 pixels.
		expect("grid tall, top outline", 10 + 30, 112, OUTLINE);
		expect("grid tall, below top outline", 10 + 30, 117, FILL);
		expect("grid tall, middle", 10 + 30, 110 + 45, FILL);
		if (failures.length > 0) throw 'OpenFL scale9Grid render wrong: ${failures.join(", ")}';
		Sys.println("OpenFL scale9Grid render ok");
	}
}
