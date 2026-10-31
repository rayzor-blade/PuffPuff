import openfl.display.Application;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import puffpuff.snapshot.Headless;

/**
 * OpenFL `scrollRect` clipping on a headless window through `openfl.display.WgpuRenderer`, at display scales 1 and 2:
 * shapes, a bitmap and text overflowing a clipped container, a scrolled container, nested clips, and siblings drawn
 * after a clip that must not stay clipped. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLClipScene.hx
 */
class OpenFLClipScene {
	static inline var W = 300;
	static inline var H = 200;
	static inline var BACKGROUND = 0x14181F;

	static function rect(color:Int, x:Float, y:Float, w:Float, h:Float):Shape {
		var s = new Shape();
		s.graphics.beginFill(color);
		s.graphics.drawRect(x, y, w, h);
		s.graphics.endFill();
		return s;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;

		// A: a 100 x 60 window onto a larger scene.
		var a = new Sprite();
		a.x = 10;
		a.y = 10;
		a.scrollRect = new Rectangle(0, 0, 100, 60);
		a.addChild(rect(0xCC3333, 0, 0, 200, 200));
		var circle = new Shape();
		circle.graphics.beginFill(0x33CC66);
		circle.graphics.drawCircle(85, 40, 30);
		circle.graphics.endFill();
		a.addChild(circle);
		var pixels = new BitmapData(32, 32, false, 0xFF3366FF);
		var bitmap = new Bitmap(pixels);
		bitmap.x = 60;
		bitmap.y = 30;
		bitmap.scaleX = bitmap.scaleY = 3;
		a.addChild(bitmap);
		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF);
		label.autoSize = TextFieldAutoSize.LEFT;
		label.selectable = false;
		label.text = "Text running past the clip edge";
		label.x = 20;
		label.y = 6;
		a.addChild(label);
		stage.addChild(a);

		// A sibling drawn after A, partly where A is clipped away: the clip must have ended.
		stage.addChild(rect(0xFFFFFF, 122, 12, 28, 28));

		// B: scrolled, so the window shows the part of the content that starts at (50, 50).
		var b = new Sprite();
		b.x = 160;
		b.y = 10;
		b.scrollRect = new Rectangle(50, 50, 80, 60);
		b.addChild(rect(0x3344AA, 0, 0, 300, 300));
		b.addChild(rect(0xFFDD00, 60, 60, 20, 20));
		stage.addChild(b);

		// C holds D, and what D shows is the part inside both.
		var c = new Sprite();
		c.x = 10;
		c.y = 100;
		c.scrollRect = new Rectangle(0, 0, 120, 80);
		var d = new Sprite();
		d.x = 60;
		d.y = 20;
		d.scrollRect = new Rectangle(0, 0, 100, 50);
		d.addChild(rect(0xCC33CC, 0, 0, 300, 300));
		c.addChild(d);
		stage.addChild(c);

		stage.addChild(rect(0x33CCCC, 160, 130, 100, 40));
		return app;
	}

	static function main():Void {
		check("openfl-clip-scene-1x", 1.0);
		check("openfl-clip-scene", 2.0);
		Sys.println("OpenFL clip render ok");
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

		// A: inside the window, and not beyond its right and bottom edges.
		expect("A inside", 10 + 5, 10 + 55, 0xCC3333);
		expect("A circle inside", 10 + 95, 10 + 28, 0x33CC66);
		expect("A right of the clip", 10 + 105, 10 + 20, BACKGROUND);
		expect("A circle past the clip", 10 + 105, 10 + 40, BACKGROUND);
		expect("A below the clip", 10 + 50, 10 + 65, BACKGROUND);
		expect("A bitmap past the bottom", 10 + 70, 10 + 70, BACKGROUND);
		expect("A bitmap inside", 10 + 70, 10 + 40, 0x3366FF);
		// The text is cut at the right edge: nothing of it past x = 110.
		var textPast = false;
		for (y in 10...70)
			for (x in 111...140) {
				var p = at(x, y);
				if (Math.abs(((p >> 16) & 0xFF) - 0xFF) < 30 && Math.abs(((p >> 8) & 0xFF) - 0xFF) < 30 && x < 122) textPast = true;
			}
		if (textPast) failures.push("text is drawn past the clip edge");
		// The sibling drawn after A is not clipped.
		expect("sibling after the clip", 122 + 14, 12 + 14, 0xFFFFFF);

		// B: the content from (50, 50) is at the window's corner.
		expect("B yellow marker", 160 + 15, 10 + 15, 0xFFDD00);
		expect("B before the marker", 160 + 5, 10 + 5, 0x3344AA);
		expect("B blue inside", 160 + 40, 10 + 30, 0x3344AA);
		expect("B right of the window", 160 + 85, 10 + 30, BACKGROUND);
		expect("B below the window", 160 + 40, 10 + 65, BACKGROUND);

		// C and D: only the part inside both.
		expect("D inside both", 10 + 90, 100 + 40, 0xCC33CC);
		expect("D right of C", 10 + 125, 100 + 40, BACKGROUND);
		expect("D below D's window", 10 + 90, 100 + 75, BACKGROUND);
		expect("D left of D's window", 10 + 55, 100 + 40, BACKGROUND);
		expect("last sibling", 160 + 50, 130 + 20, 0x33CCCC);

		if (failures.length > 0) throw 'OpenFL clip render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
