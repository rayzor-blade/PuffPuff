import openfl.display.Application;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import puffpuff.snapshot.Headless;

/**
 * `DisplayObject.mask` on a headless window through `openfl.display.WgpuRenderer`, at display scales 1 and 2: a circle
 * mask over content of two colors, a half transparent mask that lets half of the content through, a masked
 * `TextField`, and siblings that must not be masked. The masks themselves are not drawn. Needs OpenFL with
 * `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLMaskScene.hx
 */
class OpenFLMaskScene {
	static inline var W = 280;
	static inline var H = 190;
	static inline var BACKGROUND = 0x14181F;

	static function rect(color:Int, x:Float, y:Float, w:Float, h:Float, alpha = 1.0):Shape {
		var s = new Shape();
		s.graphics.beginFill(color, alpha);
		s.graphics.drawRect(x, y, w, h);
		s.graphics.endFill();
		return s;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;

		// A circle over content of two colors.
		var content = new Sprite();
		content.addChild(rect(0xCC3333, 10, 10, 100, 50));
		content.addChild(rect(0x3366FF, 10, 60, 100, 50));
		var circle = new Shape();
		circle.graphics.beginFill(0xFFFFFF);
		circle.graphics.drawCircle(60, 60, 40);
		circle.graphics.endFill();
		stage.addChild(content);
		stage.addChild(circle);
		content.mask = circle;

		// A half transparent mask over the left half of some content.
		var soft = rect(0x00FF00, 130, 10, 100, 60);
		var softMask = rect(0xFFFFFF, 130, 10, 50, 60, 0.5);
		stage.addChild(soft);
		stage.addChild(softMask);
		soft.mask = softMask;

		// A TextField cut by a rectangle.
		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 16, 0xFFFFFF);
		label.autoSize = TextFieldAutoSize.LEFT;
		label.selectable = false;
		label.text = "Masked text that goes on and on";
		label.x = 10;
		label.y = 130;
		var labelMask = rect(0xFFFFFF, 10, 125, 110, 40);
		stage.addChild(label);
		stage.addChild(labelMask);
		label.mask = labelMask;

		// Siblings after masked objects are not masked.
		stage.addChild(rect(0xFFDD00, 160, 100, 40, 30));
		stage.addChild(rect(0x33CCCC, 160, 140, 100, 30));
		return app;
	}

	static function main():Void {
		check("openfl-mask-scene-1x", 1.0);
		check("openfl-mask-scene", 2.0);
		Sys.println("OpenFL mask render ok");
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

		// The circle: content inside it, background where the content is but the circle is not, and no white mask.
		expect("circle, red part", 60, 40, 0xCC3333);
		expect("circle, blue part", 60, 85, 0x3366FF);
		expect("content outside the circle", 15, 15, BACKGROUND);
		expect("content outside the circle, bottom", 105, 105, BACKGROUND);
		expect("mask is not drawn where there is no content", 60 + 38, 60 + 1, 0x3366FF);

		// The soft mask: half of the green over the background, nothing where the mask ends, and no white.
		expect("soft mask, covered half", 130 + 25, 40, 0x0A8B0F, 8);
		expect("soft mask, past the mask", 130 + 75, 40, BACKGROUND);

		// The text is cut at the mask's right edge: nothing of it beyond x = 120.
		var past = false, inside = false;
		for (y in 125...165)
			for (x in 10...160) {
				var p = at(x, y);
				var bright = ((p >> 16) & 0xFF) > 150 && ((p >> 8) & 0xFF) > 150 && (p & 0xFF) > 150;
				if (bright && x >= 121) past = true;
				if (bright && x < 120) inside = true;
			}
		if (past) failures.push("masked text is drawn beyond the mask");
		if (!inside) failures.push("masked text is not drawn inside the mask");

		// Siblings drawn afterwards.
		expect("sibling, yellow", 160 + 20, 100 + 15, 0xFFDD00);
		expect("sibling, cyan", 160 + 50, 140 + 15, 0x33CCCC);

		if (failures.length > 0) throw 'OpenFL mask render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
