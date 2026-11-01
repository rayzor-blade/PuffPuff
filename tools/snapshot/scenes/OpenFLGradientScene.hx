import openfl.display.Application;
import openfl.display.GradientType;
import openfl.display.Shape;
import openfl.display.SpreadMethod;
import openfl.geom.Matrix;
import puffpuff.snapshot.Headless;

/**
 * OpenFL gradient fills and gradient line styles on a headless window through `openfl.display.WgpuRenderer`,
 * at display scales 1 and 2. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLGradientScene.hx
 */
class OpenFLGradientScene {
	static inline var W = 480;
	static inline var H = 290;
	static inline var BACKGROUND = 0x14181F;
	static final NINE_COLORS = [0xFF0000, 0x0000FF, 0xFF0000, 0x0000FF, 0xFF0000, 0x0000FF, 0xFF0000, 0x0000FF, 0xFF0000];
	static final NINE_RATIOS = [0, 32, 64, 96, 128, 159, 191, 223, 255];

	static function box(w:Float, h:Float, rotation:Float, tx:Float, ty:Float):Matrix {
		var m = new Matrix();
		m.createGradientBox(w, h, rotation, tx, ty);
		return m;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var shape = new Shape();
		var g = shape.graphics;

		// A: linear, red to blue.
		g.beginGradientFill(GradientType.LINEAR, [0xFF0000, 0x0000FF], [1, 1], [0, 255], box(150, 60, 0, 10, 10));
		g.drawRect(10, 10, 150, 60);
		g.endFill();

		// B: linear, repeating twice over the rectangle.
		g.beginGradientFill(GradientType.LINEAR, [0x00FF00, 0xFFFFFF], [1, 1], [0, 255], box(75, 60, 0, 170, 10), SpreadMethod.REPEAT);
		g.drawRect(170, 10, 150, 60);
		g.endFill();

		// C: linear, reflecting.
		g.beginGradientFill(GradientType.LINEAR, [0xFFAA00, 0x0033AA], [1, 1], [0, 255], box(70, 60, 0, 330, 10), SpreadMethod.REFLECT);
		g.drawRect(330, 10, 140, 60);
		g.endFill();

		// D: radial, three stops.
		g.beginGradientFill(GradientType.RADIAL, [0xFFFF00, 0xFF0000, 0x200030], [1, 1, 1], [0, 128, 255], box(120, 120, 0, 20, 80));
		g.drawCircle(80, 140, 60);
		g.endFill();

		// E: radial in a wide box, so its rings are ellipses.
		g.beginGradientFill(GradientType.RADIAL, [0xFFFFFF, 0x102060], [1, 1], [0, 255], box(160, 100, 0, 170, 90));
		g.drawRect(170, 90, 160, 100);
		g.endFill();

		// F: a gradient line.
		g.lineStyle(14, 0, 1, false, "normal", "none");
		g.lineGradientStyle(GradientType.LINEAR, [0xFF00FF, 0x00FFFF], [1, 1], [0, 255], box(130, 14, 0, 340, 143));
		g.moveTo(340, 150);
		g.lineTo(470, 150);
		g.lineStyle();

		// F: a radial gradient whose focus is near the right rim.
		g.beginGradientFill(GradientType.RADIAL, [0xFFFFFF, 0x102060], [1, 1], [0, 255], box(120, 56, 0, 345, 82), SpreadMethod.PAD,
			openfl.display.InterpolationMethod.RGB, 0.8);
		g.drawRect(345, 82, 120, 56);
		g.endFill();

		// G: six stops, a rainbow.
		g.beginGradientFill(GradientType.LINEAR, [0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF], [1, 1, 1, 1, 1, 1],
			[0, 51, 102, 153, 204, 255], box(460, 28, 0, 10, 215));
		g.drawRect(10, 215, 460, 28);
		g.endFill();

		// H: nine stops, alternating, which take three paint records.
		g.beginGradientFill(GradientType.LINEAR, NINE_COLORS, [1, 1, 1, 1, 1, 1, 1, 1, 1], NINE_RATIOS, box(460, 28, 0, 10, 247));
		g.drawRect(10, 247, 460, 28);
		g.endFill();

		window.stage.addChild(shape);
		return app;
	}

	static function main():Void {
		check("openfl-gradient-scene-1x", 1.0);
		check("openfl-gradient-scene", 2.0);
		Sys.println("OpenFL gradient render ok");
	}

	static function check(name:String, scale:Float):Void {
		var result = Headless.render(name, W, H, build, scale);
		var failures = [];
		function at(x:Float, y:Float):Int {
			var i = (Std.int(y * scale) * result.width + Std.int(x * scale)) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		function expect(label:String, x:Float, y:Float, rgb:Int, tolerance = 10):Void {
			var got = at(x, y);
			if (Math.abs(((got >> 16) & 0xFF) - ((rgb >> 16) & 0xFF)) > tolerance || Math.abs(((got >> 8) & 0xFF) - ((rgb >> 8) & 0xFF)) > tolerance
				|| Math.abs((got & 0xFF) - (rgb & 0xFF)) > tolerance)
				failures.push('$label ${StringTools.hex(got, 6)} not ${StringTools.hex(rgb, 6)}');
		}
		function same(label:String, x0:Float, y0:Float, x1:Float, y1:Float, tolerance = 8):Void {
			expect(label, x1, y1, at(x0, y0), tolerance);
		}

		expect("linear start", 12, 40, 0xFF0000, 14);
		expect("linear middle", 85, 40, 0x808080 & 0xFF0000 | 0x000080, 14);
		expect("linear end", 158, 40, 0x0000FF, 14);
		same("repeat", 170 + 75 * 0.25, 40, 170 + 75 * 1.25, 40);
		same("reflect", 330 + 70 * 0.75, 40, 330 + 70 * 1.25, 40);
		expect("radial centre", 80, 140, 0xFFFF00, 8);
		expect("radial middle", 80 + 30, 140, 0xFF0000, 24);
		expect("radial rim", 80 + 58, 140, 0x200030, 40);
		same("ellipse rings", 250 + 72, 140, 250, 140 + 45, 10);
		expect("line start", 344, 150, 0xFF00FF, 24);
		expect("line end", 466, 150, 0x00FFFF, 24);
		expect("rainbow start", 14, 229, 0xFF0000, 24);
		expect("rainbow end", 466, 229, 0xFF00FF, 24);
		expect("focal point", 453, 110, 0xFFFFFF, 20);
		expect("far from the focus", 396, 110, 0x8089AB, 24);
		expect("near the rim by the focus", 462, 110, 0x4C5888, 24);
		var rainbow = [0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF];
		for (i in 1...5)
			expect('rainbow stop $i', 10 + 460 * i / 5, 229, rainbow[i], 24);
		for (i in 1...8)
			expect('nine stops $i', 10 + 460 * NINE_RATIOS[i] / 255, 261, NINE_COLORS[i], 28);

		if (failures.length > 0) throw 'OpenFL gradient render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
