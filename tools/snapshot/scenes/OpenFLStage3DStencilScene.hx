import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DClearMask;
import openfl.display3D.Context3DCompareMode;
import openfl.display3D.Context3DStencilAction;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.Context3DTriangleFace;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.Program3D;
import openfl.display3D.VertexBuffer3D;
import openfl.display3D.textures.Texture;
import openfl.events.Event;
import openfl.geom.Matrix3D;
import openfl.Vector;
import puffpuff.snapshot.Headless;

/**
 * Stage3D stencil on WebGPU. A rectangle is written into the stencil buffer without drawing color; a red quad over the whole
 * frame then passes only where the stencil equals 1, and a blue one only where it does not. Then the stencil alone is cleared
 * to 1, so a green strip over the blue area passes the same test. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLStage3DStencilScene.hx
 */
class OpenFLStage3DStencilScene {
	static inline var W = 96;
	static inline var H = 64;

	static var context:Context3D;
	static var program:Program3D;
	static var vertices:VertexBuffer3D;
	static var indices:IndexBuffer3D;
	static var red:Texture;
	static var blue:Texture;
	static var green:Texture;
	static var created = false;

	static function color(rgb:Int):Texture {
		var texture = context.createTexture(4, 4, Context3DTextureFormat.BGRA, false);
		texture.uploadFromBitmapData(new BitmapData(4, 4, false, rgb));
		return texture;
	}

	/** A quad covering the pixel rectangle. **/
	static function draw(x:Float, y:Float, w:Float, h:Float, texture:Texture):Void {
		var m = new Matrix3D();
		m.appendScale(2 * w / W, 2 * h / H, 1);
		m.appendTranslation(-1 + 2 * x / W, 1 - 2 * (y + h) / H, 0);
		program.setMatrixParameter("placement", m);
		context.setTextureAt(program.textureSlot("image"), texture);
		context.drawTriangles(indices);
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: 0x202020}});
		var stage:openfl.display.Stage = window.stage;
		var stage3D:openfl.display.Stage3D = stage.stage3Ds.get(0);
		stage3D.addEventListener(Event.CONTEXT3D_CREATE, _ -> {
			context = stage3D.context3D;
			context.configureBackBuffer(W, H, 0, true);
			program = context.createProgram();
			program.uploadHXSL(QuadShader);
			vertices = context.createVertexBuffer(4, 5);
			vertices.uploadFromVector(Vector.ofArray([0.0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0]), 0, 4);
			indices = context.createIndexBuffer(6);
			indices.uploadFromVector(Vector.ofArray([0, 1, 2, 0, 2, 3]), 0, 6);
			red = color(0xFF0000);
			blue = color(0x0000FF);
			green = color(0x00FF00);
			created = true;
		});
		stage3D.requestContext3D();

		stage.addEventListener(Event.ENTER_FRAME, _ -> {
			if (!created) return;
			context.clear(0.125, 0.125, 0.125, 1);
			context.setProgram(program);
			context.setVertexBufferAt(program.inputLocation("position"), vertices, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(program.inputLocation("uv"), vertices, 3, Context3DVertexBufferFormat.FLOAT_2);

			// Write 1 where the rectangle is, drawing no color.
			context.setColorMask(false, false, false, false);
			context.setStencilReferenceValue(1);
			context.setStencilActions(Context3DTriangleFace.FRONT_AND_BACK, Context3DCompareMode.ALWAYS, Context3DStencilAction.SET);
			draw(24, 16, 48, 32, red);
			context.setColorMask(true, true, true, true);

			// Red where the stencil is 1, then blue where it is not.
			context.setStencilActions(Context3DTriangleFace.FRONT_AND_BACK, Context3DCompareMode.EQUAL, Context3DStencilAction.KEEP);
			draw(0, 0, W, H, red);
			context.setStencilActions(Context3DTriangleFace.FRONT_AND_BACK, Context3DCompareMode.NOT_EQUAL, Context3DStencilAction.KEEP);
			draw(0, 0, W, H, blue);

			// Clearing only the stencil leaves the color: the strip passes where the stencil was 0 a moment ago.
			context.clear(0, 0, 0, 0, 1, 1, Context3DClearMask.STENCIL);
			context.setStencilActions(Context3DTriangleFace.FRONT_AND_BACK, Context3DCompareMode.EQUAL, Context3DStencilAction.KEEP);
			draw(78, 0, 12, H, green);
			context.setStencilActions();
			context.present();
		});
		return app;
	}

	static function main():Void {
		var result = Headless.render("openfl-stage3d-stencil-scene", W, H, build, 1.0, 3);
		var failures = [];
		function at(x:Int, y:Int):Int {
			var i = (y * W + x) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		function expect(name:String, x:Int, y:Int, rgb:Int):Void {
			if (at(x, y) != rgb) failures.push('$name at $x,$y is ${StringTools.hex(at(x, y), 6)}, expected ${StringTools.hex(rgb, 6)}');
		}
		if (!created) failures.push("no context was created");
		expect("inside the rectangle", 48, 32, 0xFF0000);
		expect("rectangle corner", 26, 18, 0xFF0000);
		expect("outside, left", 8, 32, 0x0000FF);
		expect("outside, above", 48, 8, 0x0000FF);
		expect("outside, corner", 93, 58, 0x0000FF);
		expect("strip after the stencil clear", 84, 32, 0x00FF00);
		expect("inside the rectangle, kept", 60, 32, 0xFF0000);
		if (failures.length > 0) throw 'OpenFL Stage3D stencil render wrong: ${failures.join(", ")}';
		Sys.println("OpenFL Stage3D stencil render ok");
	}
}
