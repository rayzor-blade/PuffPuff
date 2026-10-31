import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DMipFilter;
import openfl.display3D.Context3DTextureFilter;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.Context3DWrapMode;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.Program3D;
import openfl.display3D.VertexBuffer3D;
import openfl.display3D.textures.RectangleTexture;
import openfl.display3D.textures.Texture;
import openfl.events.Event;
import openfl.geom.Matrix3D;
import openfl.Vector;
import puffpuff.snapshot.Headless;

/**
 * Stage3D texture levels and samplers on WebGPU. A 64x64 texture holds a different color in each mip level, and the same
 * texture is drawn at 32, 16 and 8 pixels, so the sampler picks level 1, 2 and 3. With no mip filter it stays on level 0.
 * A `RectangleTexture` is drawn beside them. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLStage3DMipScene.hx
 */
class OpenFLStage3DMipScene {
	static inline var W = 240;
	static inline var H = 64;
	static inline var TOP = 8;

	static var levelColors = [0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0x00FFFF, 0xFF00FF, 0xFFFFFF];
	static var context:Context3D;
	static var program:Program3D;
	static var vertices:VertexBuffer3D;
	static var indices:IndexBuffer3D;
	static var mipped:Texture;
	static var rect:RectangleTexture;
	static var created = false;

	/** Pixel size and left edge of each quad: levels 1, 2 and 3 with mip filtering, level 0 without, and the rectangle texture. **/
	static var quads = [
		{x: 8, size: 32, mip: Context3DMipFilter.MIPLINEAR, rect: false},
		{x: 52, size: 16, mip: Context3DMipFilter.MIPLINEAR, rect: false},
		{x: 76, size: 8, mip: Context3DMipFilter.MIPNEAREST, rect: false},
		{x: 92, size: 16, mip: Context3DMipFilter.MIPNONE, rect: false},
		{x: 120, size: 16, mip: Context3DMipFilter.MIPNONE, rect: true},
	];

	static function solid(size:Int, rgb:Int):BitmapData
		return new BitmapData(size, size, false, rgb);

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: 0x202020}});
		var stage:openfl.display.Stage = window.stage;
		var stage3D:openfl.display.Stage3D = stage.stage3Ds.get(0);
		stage3D.addEventListener(Event.CONTEXT3D_CREATE, _ -> {
			context = stage3D.context3D;
			context.configureBackBuffer(W, H, 0, false);
			program = context.createProgram();
			program.uploadHXSL(QuadShader);

			vertices = context.createVertexBuffer(4, 5);
			vertices.uploadFromVector(Vector.ofArray([0.0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0]), 0, 4);
			indices = context.createIndexBuffer(6);
			indices.uploadFromVector(Vector.ofArray([0, 1, 2, 0, 2, 3]), 0, 6);

			mipped = context.createTexture(64, 64, Context3DTextureFormat.BGRA, false);
			for (level in 0...7) mipped.uploadFromBitmapData(solid(64 >> level, levelColors[level]), level);
			rect = context.createRectangleTexture(8, 8, Context3DTextureFormat.BGRA, false);
			rect.uploadFromBitmapData(solid(8, 0x00C800));
			created = true;
		});
		stage3D.requestContext3D();

		stage.addEventListener(Event.ENTER_FRAME, _ -> {
			if (!created) return;
			context.clear(0.125, 0.125, 0.125, 1);
			context.setProgram(program);
			context.setVertexBufferAt(program.inputLocation("position"), vertices, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(program.inputLocation("uv"), vertices, 3, Context3DVertexBufferFormat.FLOAT_2);
			var slot = program.textureSlot("image");
			for (q in quads) {
				var m = new Matrix3D();
				m.appendScale(2 * q.size / W, 2 * q.size / H, 1);
				m.appendTranslation(-1 + 2 * q.x / W, 1 - 2 * (TOP + q.size) / H, 0);
				program.setMatrixParameter("placement", m);
				context.setTextureAt(slot, q.rect ? rect : mipped);
				context.setSamplerStateAt(slot, Context3DWrapMode.CLAMP, Context3DTextureFilter.LINEAR, q.mip);
				context.drawTriangles(indices);
			}
			context.present();
		});
		return app;
	}

	static function main():Void {
		var result = Headless.render("openfl-stage3d-mip-scene", W, H, build, 1.0, 5);
		var failures = [];
		function at(x:Int, y:Int):Int {
			var i = (y * W + x) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		if (!created) failures.push("no context was created");
		var expected = [levelColors[1], levelColors[2], levelColors[3], levelColors[0], 0x00C800];
		for (i in 0...quads.length) {
			var q = quads[i];
			var got = at(q.x + (q.size >> 1), TOP + (q.size >> 1));
			if (got != expected[i]) failures.push('quad $i is ${StringTools.hex(got, 6)}, expected ${StringTools.hex(expected[i], 6)}');
		}
		if (at(2, 2) != 0x202020) failures.push('background ${StringTools.hex(at(2, 2), 6)}');
		if (failures.length > 0) throw 'OpenFL Stage3D mip render wrong: ${failures.join(", ")}';
		Sys.println("OpenFL Stage3D mip render ok");
	}
}
