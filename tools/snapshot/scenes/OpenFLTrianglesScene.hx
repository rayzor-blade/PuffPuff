import openfl.Vector;
import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.TriangleCulling;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * `Graphics.drawTriangles` and bitmap-filled rectangles on a headless window through `openfl.display.WgpuRenderer`, at display
 * scales 1 and 2: indexed triangles with three and two values of texture data a vertex, texture coordinates taken from the
 * vertices, culling by winding on a solid fill, and rectangles filled with a scaled bitmap and a repeating one. Needs OpenFL with
 * `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLTrianglesScene.hx
 */
class OpenFLTrianglesScene {
	static inline var W = 280;
	static inline var H = 190;
	static inline var BACKGROUND = 0x14181F;
	static inline var RED = 0xFF0000;
	static inline var GREEN = 0x00FF00;
	static inline var BLUE = 0x0000FF;
	static inline var YELLOW = 0xFFFF00;

	/** Red top left, green top right, blue bottom left, yellow bottom right. **/
	static function sheet():BitmapData {
		var bd = new BitmapData(64, 64, true, 0xFFFF0000);
		bd.fillRect(new Rectangle(32, 0, 32, 32), 0xFF00FF00);
		bd.fillRect(new Rectangle(0, 32, 32, 32), 0xFF0000FF);
		bd.fillRect(new Rectangle(32, 32, 32, 32), 0xFFFFFF00);
		return bd;
	}

	static function floats(values:Array<Float>):Vector<Float> {
		return Vector.ofArray(values);
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;
		var bitmap = sheet();

		// Two indexed triangles over the whole sheet, with three values of texture data a vertex.
		var indexed = new Shape();
		indexed.graphics.beginBitmapFill(bitmap, null, false, false);
		indexed.graphics.drawTriangles(floats([10, 10, 74, 10, 10, 74, 74, 74]), Vector.ofArray([0, 1, 2, 2, 1, 3]),
			floats([0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1]));
		stage.addChild(indexed);

		// No texture data: a vertex takes the bitmap position of its own coordinates, repeating.
		var automatic = new Shape();
		automatic.graphics.beginBitmapFill(bitmap, null, true, false);
		automatic.graphics.drawTriangles(floats([90, 10, 154, 10, 90, 74, 154, 74]), Vector.ofArray([0, 1, 2, 2, 1, 3]));
		stage.addChild(automatic);

		// Two values a vertex, on the bottom right quarter of the sheet only.
		var partial = new Shape();
		partial.graphics.beginBitmapFill(bitmap, null, false, false);
		partial.graphics.drawTriangles(floats([240, 130, 272, 130, 240, 162, 272, 162]), Vector.ofArray([0, 1, 2, 2, 1, 3]),
			floats([0.5, 0.5, 1, 0.5, 0.5, 1, 1, 1]));
		stage.addChild(partial);

		// One triangle of each winding on a solid fill.
		function pair(culling:TriangleCulling, y:Float):Void {
			var s = new Shape();
			s.graphics.beginFill(0xFF8800);
			s.graphics.drawTriangles(floats([170, y, 210, y, 170, y + 40, 220, y, 220, y + 40, 260, y]), null, null, culling);
			s.graphics.endFill();
			stage.addChild(s);
		}
		pair(TriangleCulling.POSITIVE, 10);
		pair(TriangleCulling.NEGATIVE, 60);

		// A rectangle filled with the bitmap at twice its size.
		var scaled = new Shape();
		scaled.graphics.beginBitmapFill(bitmap, new Matrix(2, 0, 0, 2, 10, 100), false, false);
		scaled.graphics.drawRect(10, 100, 100, 80);
		scaled.graphics.endFill();
		stage.addChild(scaled);

		// A rectangle filled with the repeating bitmap.
		var tiled = new Shape();
		tiled.graphics.beginBitmapFill(bitmap, new Matrix(1, 0, 0, 1, 130, 100), true, false);
		tiled.graphics.drawRect(130, 100, 100, 80);
		tiled.graphics.endFill();
		stage.addChild(tiled);
		return app;
	}

	static function main():Void {
		check("openfl-triangles-scene-1x", 1.0);
		check("openfl-triangles-scene", 2.0);
		Sys.println("OpenFL triangles render ok");
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

		expect("indexed, red", 20, 20, RED);
		expect("indexed, green", 60, 20, GREEN);
		expect("indexed, blue", 20, 60, BLUE);
		expect("indexed, yellow", 60, 60, YELLOW);

		// Pixel x of the bitmap is the position modulo 64: 95 gives 31 (red), 100 gives 36 (green).
		expect("automatic, red", 95, 20, RED);
		expect("automatic, green", 100, 20, GREEN);
		expect("automatic, yellow", 100, 60, YELLOW);
		expect("automatic, blue", 95, 60, BLUE);

		expect("partial, only yellow", 245, 135, YELLOW);
		expect("partial, only yellow, far corner", 268, 158, YELLOW);

		// Positive culling keeps the triangle wound against the first (area below zero), negative the first.
		expect("positive culling keeps the second", 225, 20, 0xFF8800);
		expect("positive culling drops the first", 175, 15, BACKGROUND);
		expect("negative culling keeps the first", 175, 65, 0xFF8800);
		expect("negative culling drops the second", 225, 70, BACKGROUND);

		expect("scaled, red", 18, 108, RED);
		expect("scaled, green", 90, 108, GREEN);
		expect("scaled, blue", 18, 170, BLUE);
		expect("scaled, yellow", 90, 170, YELLOW);
		expect("scaled, outside", 115, 140, BACKGROUND);

		// Past the bitmap's edge the tiles repeat: 70 wraps to 6 (red) and 40 stays green.
		expect("tiled, wrapped red", 130 + 70, 100 + 10, RED);
		expect("tiled, green", 130 + 40, 100 + 10, GREEN);
		expect("tiled, wrapped down", 130 + 40, 100 + 70, GREEN);
		expect("tiled, yellow", 130 + 40, 100 + 40, YELLOW);

		if (failures.length > 0) throw 'OpenFL triangles render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
