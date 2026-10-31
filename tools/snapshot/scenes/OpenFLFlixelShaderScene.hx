import flixel.graphics.tile.FlxGraphicsShader;
import openfl.Vector;
import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display3D.Context3DTextureFilter;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * HaxeFlixel custom shader written in HXSL the way a game would: extends `FlxGraphicsShader` (which Flixel's `FlxShader` names)
 * with its own source, replaces `fragment()`, and calls `flixelTexture2D` where the GLSL version calls `flixel_texture2D`.
 * Submitted the way `FlxDrawQuadsItem.render` does, at display scales 1 and 2. Needs OpenFL with `-D openfl_wgpu` and HaxeFlixel
 * with the same define:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu -cp <flixel>" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLFlixelShaderScene.hx
 */
class FlashFlxShader extends FlxGraphicsShader {
	static var SRC = {
		@:extends flixel.graphics.tile.FlxGraphicsShader;
		@param var flash:Float;
		function fragment() {
			var tex = flixelTexture2D(vUv);
			output.color = vec4(tex.rgb + vec3(flash, flash, flash) * tex.a, tex.a);
		}
	};

	public function new() {
		super();
	}
}

class OpenFLFlixelShaderScene {
	static inline var W = 120;
	static inline var H = 50;
	static inline var BACKGROUND = 0x14181F;

	/** Bottom right of the sheet is yellow, so a quad over its last 32 pixels is yellow. **/
	static function sheet():BitmapData {
		var bd = new BitmapData(64, 64, true, 0xFFFF0000);
		bd.fillRect(new Rectangle(32, 32, 32, 32), 0xFFFFFF00);
		return bd;
	}

	/** What `FlxDrawQuadsItem.render` sets on a shader, then `drawQuads`, for one quad at `x`. **/
	static function item(shape:Shape, shader:FlxGraphicsShader, bitmap:BitmapData, x:Float, alpha:Float, red:Float, green:Float, blue:Float):Void {
		shader.bitmap.input = bitmap;
		shader.bitmap.filter = LINEAR;
		var perVertex:Array<Float> = [];
		var mult:Array<Float> = [];
		var offsets:Array<Float> = [];
		for (i in 0...4) {
			perVertex.push(alpha);
			mult.push(red);
			mult.push(green);
			mult.push(blue);
			mult.push(1);
			for (k in 0...4)
				offsets.push(0);
		}
		shader.alpha.value = perVertex;
		shader.colorMultiplier.value = mult;
		shader.colorOffset.value = offsets;
		shader.hasTransform.value = [true];
		shader.hasColorTransform.value = [true];

		shape.graphics.beginShaderFill(shader);
		shape.graphics.drawQuads(Vector.ofArray([32.0, 32, 32, 32]), null, Vector.ofArray([1.0, 0, 0, 1, x, 10]));
		shape.graphics.endFill();
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;
		var bitmap = sheet();

		// Yellow times red, with the shader's flash added after the color transform.
		var opaque = new Shape();
		var one = new FlashFlxShader();
		one.flash.value = [0.25];
		item(opaque, one, bitmap, 10, 1, 1, 0, 0);
		stage.addChild(opaque);

		// Same at half alpha. The transform's alpha scales the color too.
		var half = new Shape();
		var two = new FlashFlxShader();
		two.flash.value = [0.25];
		item(half, two, bitmap, 50, 0.5, 1, 0, 0);
		stage.addChild(half);

		// Same class, no flash.
		var plain = new Shape();
		var three = new FlashFlxShader();
		three.flash.value = [0.0];
		item(plain, three, bitmap, 90, 1, 1, 1, 1);
		stage.addChild(plain);
		return app;
	}

	static function main():Void {
		check("openfl-flixel-shader-scene-1x", 1.0);
		check("openfl-flixel-shader-scene", 2.0);
		Sys.println("OpenFL Flixel shader render ok");
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

		expect("red plus flash", 26, 26, 0xFF4040);
		expect("half alpha, red plus flash over the background", 66, 26, 0xA92C2F);
		expect("no flash, yellow", 106, 26, 0xFFFF00);
		expect("outside", 45, 26, BACKGROUND);

		if (failures.length > 0) throw 'OpenFL Flixel shader renders wrong at ${scale}x: ${failures.join(", ")}';
	}
}
