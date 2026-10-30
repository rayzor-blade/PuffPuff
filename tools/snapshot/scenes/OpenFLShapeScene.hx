import openfl.display.Application;
import openfl.display.Shape;
import puffpuff.snapshot.Headless;

/**
 * An OpenFL `Stage` on a headless window (no native window) drawing vector graphics through
 * `openfl.display.WgpuRenderer` into a texture, at display scales 1 and 2. Needs OpenFL with `-D openfl_wgpu`; checks sampled pixels and writes a PNG.
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh ...
 */
class OpenFLShapeScene {
	static inline var W = 256;
	static inline var H = 192;
	static inline var BACKGROUND = 0x202830;

	static function pixel(px:haxe.io.Bytes, w:Int, x:Int, y:Int):Int {
		var i = (y * w + x) * 4;
		return (px.get(i) << 16) | (px.get(i + 1) << 8) | px.get(i + 2);
	}

	static function near(a:Int, b:Int, tolerance = 3):Bool {
		return Math.abs(((a >> 16) & 0xFF) - ((b >> 16) & 0xFF)) <= tolerance && Math.abs(((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)) <= tolerance
			&& Math.abs((a & 0xFF) - (b & 0xFF)) <= tolerance;
	}

	static function main():Void {
		check("openfl-shape-scene-1x", 1.0);
		check("openfl-shape-scene", 2.0);
		Sys.println("OpenFL shape render ok");
	}

	static function check(name:String, scale:Float):Void {
		var result = Headless.render(name, W, H, () -> {
			var app = new Application();
			var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
			var shape = new Shape();
			var g = shape.graphics;
			g.beginFill(0xE74C3C);
			g.drawRect(20, 20, 100, 80);
			g.endFill();
			g.beginFill(0x2ECC71, 0.5);
			g.drawCircle(150, 100, 50);
			g.endFill();
			g.lineStyle(6, 0xF1C40F);
			g.moveTo(20, 160);
			g.lineTo(230, 160);
			window.stage.addChild(shape);
			return app;
		}, scale);

		var pw = result.width;
		var at = (x:Int, y:Int) -> pixel(result.pixels, pw, Std.int(x * scale), Std.int(y * scale));

		var failures = [];
		if (!near(at(5, 5), BACKGROUND)) failures.push('background ${StringTools.hex(at(5, 5), 6)}');
		if (!near(at(60, 60), 0xE74C3C)) failures.push('rect ${StringTools.hex(at(60, 60), 6)}');
		// Half-transparent green over the background.
		var blended = (0x2ECC71 >> 16) / 2 + (BACKGROUND >> 16) / 2;
		if (Math.abs(((at(170, 100) >> 16) & 0xFF) - blended) > 4) failures.push('circle ${StringTools.hex(at(170, 100), 6)}');
		if (!near(at(100, 160), 0xF1C40F, 6)) failures.push('line ${StringTools.hex(at(100, 160), 6)}');
		// The line style begins at the pen, which drawCircle left at the circle's edge: a lone moveTo draws no dot.
		if (!near(at(203, 100), BACKGROUND)) failures.push('stray dot ${StringTools.hex(at(203, 100), 6)}');

		if (failures.length > 0) throw 'OpenFL shape render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
