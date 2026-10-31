import openfl.Vector;
import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.GraphicsShader;
import openfl.display.Shape;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * Custom HXSL shader: extends `openfl.display.GraphicsShader`, replaces the fragment stage, and runs on a shader fill with
 * `drawQuads`. Needs OpenFL with `-D openfl_wgpu`:
 * `drawQuads` runs it. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLCustomShaderScene.hx
 */
class FlashShader extends GraphicsShader {
	static var SRC = {
		@:extends openfl.display.GraphicsShader;
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

class OpenFLCustomShaderScene {
	static inline var W = 120;
	static inline var H = 60;
	static inline var BACKGROUND = 0x14181F;

	static function quad(stage:openfl.display.DisplayObjectContainer, bitmap:BitmapData, flash:Float, x:Float):Void {
		var shape = new Shape();
		var shader = new FlashShader();
		shader.bitmap.input = bitmap;
		shader.flash.value = [flash];
		shape.graphics.beginShaderFill(shader);
		shape.graphics.drawQuads(Vector.ofArray([0.0, 0, 8, 8]), null, Vector.ofArray([4.0, 0, 0, 4, x, 10]));
		shape.graphics.endFill();
		stage.addChild(shape);
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;
		var bitmap = new BitmapData(8, 8, true, 0xFF200000);

		// One shader class and one texture, with a different parameter value per draw.
		quad(stage, bitmap, 0.5, 10);
		quad(stage, bitmap, 0.0, 50);
		quad(stage, bitmap, 1.0, 90);
		return app;
	}

	static function main():Void {
		check("openfl-custom-shader-scene-1x", 1.0);
		check("openfl-custom-shader-scene", 2.0);
		Sys.println("OpenFL custom shader render ok");
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

		// Texture is 0x200000. The shader adds the parameter, scaled by alpha, to each channel.
		expect("flash 0.5", 25, 25, 0x9F8080);
		expect("flash 0", 65, 25, 0x200000);
		expect("flash 1", 105, 25, 0xFFFFFF);
		expect("outside", 45, 25, BACKGROUND);

		if (failures.length > 0) throw 'OpenFL custom shader renders wrong at ${scale}x: ${failures.join(", ")}';
	}
}
