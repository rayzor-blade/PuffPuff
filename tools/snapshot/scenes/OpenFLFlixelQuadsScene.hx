import flixel.graphics.tile.FlxGraphicsShader;
import openfl.Vector;
import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Shape;
import openfl.display3D.Context3DTextureFilter;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * Draws what HaxeFlixel's `FlxDrawQuadsItem` submits (`overrideBlendMode`, `beginShaderFill(FlxGraphicsShader)`, `drawQuads`) on a
 * headless window through `openfl.display.WgpuRenderer`, at display scales 1 and 2. Covers per-quad alpha and color multiplier,
 * additive blend, color offsets, and nearest and linear sampling. Needs OpenFL with `-D openfl_wgpu` and the HaxeFlixel sources:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu -cp <flixel>" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLFlixelQuadsScene.hx
 */
class OpenFLFlixelQuadsScene {
	static inline var W = 240;
	static inline var H = 70;
	static inline var BACKGROUND = 0x14181F;
	static inline var RED = 0xFF0000;
	static inline var GREEN = 0x00FF00;
	static inline var YELLOW = 0xFFFF00;

	/** Red top left, green top right, blue bottom left, yellow bottom right. **/
	static function sheet():BitmapData {
		var bd = new BitmapData(64, 64, true, 0xFFFF0000);
		bd.fillRect(new Rectangle(32, 0, 32, 32), 0xFF00FF00);
		bd.fillRect(new Rectangle(0, 32, 32, 32), 0xFF0000FF);
		bd.fillRect(new Rectangle(32, 32, 32, 32), 0xFFFFFF00);
		return bd;
	}

	/** One draw the way `FlxDrawQuadsItem.render` makes it. `multipliers` has red, green and blue per quad. **/
	static function item(shape:Shape, bitmap:BitmapData, filter:Context3DTextureFilter, blend:BlendMode, rects:Array<Float>, transforms:Array<Float>,
			alphas:Array<Float>, ?multipliers:Array<Float>, ?quadOffsets:Array<Float>):Void {
		var shader = new FlxGraphicsShader();
		shader.bitmap.input = bitmap;
		shader.bitmap.filter = filter;

		var perVertex:Array<Float> = [];
		for (a in alphas)
			for (i in 0...4)
				perVertex.push(a);
		shader.alpha.value = perVertex;

		if (multipliers != null) {
			var mult:Array<Float> = [], offsets:Array<Float> = [];
			for (q in 0...Std.int(multipliers.length / 3))
				for (i in 0...4) {
					mult.push(multipliers[q * 3]);
					mult.push(multipliers[q * 3 + 1]);
					mult.push(multipliers[q * 3 + 2]);
					mult.push(1);
					for (k in 0...4)
						offsets.push(quadOffsets != null ? quadOffsets[q * 4 + k] : 0);
				}
			shader.colorMultiplier.value = mult;
			shader.colorOffset.value = offsets;
		}

		shader.hasTransform.value = [true];
		shader.hasColorTransform.value = [multipliers != null];

		shape.graphics.overrideBlendMode(blend);
		shape.graphics.beginShaderFill(shader);
		shape.graphics.drawQuads(Vector.ofArray(rects), null, Vector.ofArray(transforms));
		shape.graphics.endFill();
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;
		var bitmap = sheet();

		// Four quads in one draw: plain, half alpha, yellow times red, blue times black.
		var row = new Shape();
		item(row, bitmap, LINEAR, NORMAL, [0, 0, 32, 32, 32, 0, 32, 32, 32, 32, 32, 32, 0, 32, 32, 32],
			[1, 0, 0, 1, 10, 10, 1, 0, 0, 1, 50, 10, 1, 0, 0, 1, 90, 10, 1, 0, 0, 1, 130, 10], [1, 0.5, 1, 1],
			[1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]);
		stage.addChild(row);

		// A green quad added to a dark purple fill.
		var added = new Shape();
		added.graphics.beginFill(0x400040);
		added.graphics.drawRect(170, 10, 32, 32);
		added.graphics.endFill();
		item(added, bitmap, LINEAR, ADD, [32, 0, 32, 32], [1, 0, 0, 1, 170, 10], [1]);
		stage.addChild(added);

		// The edge between a red and a green pixel at 8x: sharp with nearest, blended with linear.
		var nearest = new Shape();
		item(nearest, bitmap, NEAREST, NORMAL, [31, 0, 2, 1], [8, 0, 0, 8, 10, 50], [1]);
		stage.addChild(nearest);

		var linear = new Shape();
		item(linear, bitmap, LINEAR, NORMAL, [31, 0, 2, 1], [8, 0, 0, 8, 50, 50], [1]);
		stage.addChild(linear);

		// Color offsets, 0 to 255 and negative, next to a plain multiplier in the same draw.
		var offset = new Shape();
		item(offset, bitmap, LINEAR, NORMAL, [32, 0, 32, 32, 0, 32, 32, 32, 32, 32, 32, 32], [0.75, 0, 0, 0.75, 100, 40, 0.75, 0, 0, 0.75, 140, 40, 0.75, 0, 0, 0.75, 180, 40],
			[1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 0, 1], [128, 0, 0, 0, 0, 0, -255, 0, 0, 0, 0, 0]);
		stage.addChild(offset);
		return app;
	}

	static function main():Void {
		check("openfl-flixel-quads-scene-1x", 1.0);
		check("openfl-flixel-quads-scene", 2.0);
		Sys.println("OpenFL Flixel quads render ok");
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

		expect("plain, red", 26, 26, RED);
		expect("half alpha, green over the background", 66, 26, 0x0A8B0F);
		expect("colour multiplier, yellow times red", 106, 26, RED);
		expect("colour multiplier, blue times black", 146, 26, 0x000000);
		expect("outside the quads", 45, 26, BACKGROUND);

		expect("additive, green over purple", 186, 26, 0x40FF40);

		// Pixel 7 of the 8-wide red texel, and pixel 9 into the green one.
		expect("nearest, red up to the edge", 10 + 7, 54, RED);
		expect("nearest, green from the edge", 10 + 9, 54, GREEN);
		expect("offset, green plus red", 110, 50, 0x80FF00);
		expect("offset, blue minus blue", 150, 50, 0x000000);
		expect("offset draw, yellow times magenta", 190, 50, RED);

		var blended = at(50 + 7.5, 54);
		var mixedRed = (blended >> 16) & 0xFF;
		if (mixedRed < 40 || mixedRed > 215) failures.push('linear, edge ${StringTools.hex(blended, 6)} is not a blend');

		if (failures.length > 0) throw 'OpenFL Flixel quads render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
