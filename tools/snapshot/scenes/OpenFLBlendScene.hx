import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.BlendMode;
import openfl.display.Shape;
import openfl.geom.ColorTransform;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import puffpuff.snapshot.Headless;

/**
 * Blend modes and color transforms on a headless window through `openfl.display.WgpuRenderer`, at display scales 1 and
 * 2, drawn over a mid gray backdrop so each result follows from the blend equation: add, multiply, screen, subtract,
 * darken and lighten, then color transforms on a shape, a bitmap and text, and a blended bitmap. Needs OpenFL with
 * `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLBlendScene.hx
 */
class OpenFLBlendScene {
	static inline var W = 260;
	static inline var H = 150;

	static function rect(color:Int, x:Float, y:Float, ?blend:BlendMode, ?transform:ColorTransform):Shape {
		var s = new Shape();
		s.graphics.beginFill(color);
		s.graphics.drawRect(x, y, 40, 40);
		s.graphics.endFill();
		if (blend != null) s.blendMode = blend;
		if (transform != null) s.transform.colorTransform = transform;
		return s;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: 0x808080}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;

		stage.addChild(rect(0x400000, 10, 10, BlendMode.ADD));
		stage.addChild(rect(0xFF8000, 60, 10, BlendMode.MULTIPLY));
		stage.addChild(rect(0x404040, 110, 10, BlendMode.SCREEN));
		stage.addChild(rect(0x202020, 160, 10, BlendMode.SUBTRACT));
		stage.addChild(rect(0x606060, 210, 10, BlendMode.DARKEN));

		stage.addChild(rect(0xA0A0A0, 10, 60, BlendMode.LIGHTEN));
		stage.addChild(rect(0x3366FF, 60, 60));
		stage.addChild(rect(0xFF0000, 110, 60, null, new ColorTransform(0.5, 1, 1, 1)));
		stage.addChild(rect(0x300000, 160, 60, null, new ColorTransform(1, 1, 1, 1, 0, 100, 0, 0)));

		var white = new Bitmap(new BitmapData(40, 40, false, 0xFFFFFFFF));
		white.x = 210;
		white.y = 60;
		white.transform.colorTransform = new ColorTransform(0.5, 0.5, 1, 1);
		stage.addChild(white);

		var added = new Bitmap(new BitmapData(40, 40, false, 0xFF404040));
		added.x = 10;
		added.y = 105;
		added.blendMode = BlendMode.ADD;
		stage.addChild(added);

		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 22, 0xFFFFFF);
		label.autoSize = TextFieldAutoSize.LEFT;
		label.selectable = false;
		label.text = "Tint";
		label.x = 60;
		label.y = 108;
		label.transform.colorTransform = new ColorTransform(1, 0.4, 0.4, 1);
		stage.addChild(label);
		return app;
	}

	static function main():Void {
		check("openfl-blend-scene-1x", 1.0);
		check("openfl-blend-scene", 2.0);
		Sys.println("OpenFL blend render ok");
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

		// The backdrop is 0x80 in every channel.
		expect("backdrop", 5, 5, 0x808080);
		expect("add", 10 + 20, 10 + 20, 0xC08080);
		expect("multiply", 60 + 20, 10 + 20, 0x804000);
		expect("screen", 110 + 20, 10 + 20, 0x9F9F9F, 8);
		expect("subtract", 160 + 20, 10 + 20, 0x606060);
		expect("darken", 210 + 20, 10 + 20, 0x606060);
		expect("lighten", 10 + 20, 60 + 20, 0xA0A0A0);
		expect("normal", 60 + 20, 60 + 20, 0x3366FF);
		expect("red halved", 110 + 20, 60 + 20, 0x800000);
		expect("green offset", 160 + 20, 60 + 20, 0x306400);
		expect("bitmap tinted", 210 + 20, 60 + 20, 0x8080FF);
		expect("bitmap added", 10 + 20, 105 + 20, 0xC0C0C0);

		// The text is tinted pink: its most distant pixel from the backdrop has more red than green.
		var best = 0, bestPixel = 0x808080;
		for (y in 105...140)
			for (x in 58...120) {
				var p = at(x, y);
				var d = Std.int(Math.abs(((p >> 16) & 0xFF) - 0x80) + Math.abs(((p >> 8) & 0xFF) - 0x80));
				if (d > best) {
					best = d;
					bestPixel = p;
				}
			}
		if (((bestPixel >> 16) & 0xFF) < 200 || ((bestPixel >> 8) & 0xFF) > 0xA0 + 0x20) failures.push('tinted text ${StringTools.hex(bestPixel, 6)} is not pink');

		if (failures.length > 0) throw 'OpenFL blend render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
