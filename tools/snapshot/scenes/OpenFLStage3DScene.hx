import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DCompareMode;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.Context3DTriangleFace;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.Program3D;
import openfl.display3D.VertexBuffer3D;
import openfl.display3D.textures.Texture;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.Vector;
import puffpuff.snapshot.Headless;

private typedef Piece = {vertices:VertexBuffer3D, indices:IndexBuffer3D, count:Int, model:lime.utils.Float32Array, x:Float, y:Float, color:Array<Float>, textured:Bool};

/**
 * OpenFL's own Stage3D API on WebGPU: `requestContext3D`, a `Program3D` from an HXSL shader, vertex and index buffers, a
 * texture from a `BitmapData`, depth test and culling, then `drawTriangles` and `present`. A torus with a sphere in its
 * hole, and a textured cube, with the display list drawn over them. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLStage3DScene.hx
 */
class OpenFLStage3DScene {
	static inline var W = 480;
	static inline var H = 300;

	static var context:Context3D;
	static var program:Program3D;
	static var texture:Texture;
	static var pieces:Array<Piece> = [];
	static var proj = Mesh3D.perspective(Meshes3D.FOV, W / H, 0.5, 20);
	static var created = false;

	static function upload(c:Context3D, mesh:Mesh3D, model:lime.utils.Float32Array, x:Float, y:Float, color:Array<Float>, textured:Bool):Void {
		var vertexCount = Std.int(mesh.vertices.length / 8);
		var vertices = c.createVertexBuffer(vertexCount, 8);
		var data = new Vector<Float>();
		for (i in 0...mesh.vertices.length) data.push(mesh.vertices[i]);
		vertices.uploadFromVector(data, 0, vertexCount);
		var indices = c.createIndexBuffer(mesh.indices.length);
		var list = new Vector<UInt>();
		for (i in mesh.indices) list.push(i);
		indices.uploadFromVector(list, 0, mesh.indices.length);
		pieces.push({vertices: vertices, indices: indices, count: Std.int(mesh.indices.length / 3), model: model, x: x, y: y, color: color, textured: textured});
	}

	static function floats(m:lime.utils.Float32Array):Array<Float>
		return [for (i in 0...16) m[i]];

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: 0x141724}});
		var stage:openfl.display.Stage = window.stage;

		var frame = 0;
		var stage3D:openfl.display.Stage3D = stage.stage3Ds.get(0);
		stage3D.addEventListener(Event.CONTEXT3D_CREATE, _ -> {
			context = stage3D.context3D;
			context.configureBackBuffer(W, H, 0, true);

			program = context.createProgram();
			program.uploadHXSL(LitShader);

			texture = context.createTexture(64, 64, Context3DTextureFormat.BGRA, false);
			var checker = new BitmapData(64, 64, false, 0);
			for (y in 0...64)
				for (x in 0...64) checker.setPixel(x, y, ((x >> 3) + (y >> 3)) & 1 == 0 ? 0xF5D75A : 0x4678EB);
			texture.uploadFromBitmapData(checker);

			var turn = 0.4;
			upload(context, Mesh3D.torus(1.0, 0.3, 48, 24), Mesh3D.mul(Mesh3D.rotateX(1.0), Mesh3D.rotateY(turn)), Meshes3D.LEFT, 0, [1.0, 0.55, 0.2, 1.0], false);
			upload(context, Mesh3D.sphere(0.5, 24, 32), Mesh3D.identity(), Meshes3D.LEFT, 0, [0.25, 0.8, 0.75, 1.0], false);
			upload(context, Mesh3D.cube(0.8), Mesh3D.mul(Mesh3D.rotateY(turn + 0.6), Mesh3D.rotateX(0.35)), Meshes3D.RIGHT, 0, [1.0, 1.0, 1.0, 1.0], true);
			created = true;
		});
		stage3D.requestContext3D();

		stage.addEventListener(Event.ENTER_FRAME, _ -> {
			if (!created) return;

			context.clear(0.08, 0.09, 0.14, 1, 1);
			context.setDepthTest(true, Context3DCompareMode.LESS);
			context.setCulling(Context3DTriangleFace.BACK);
			context.setProgram(program);
			program.setParameter("lightDir", [-0.5, 0.6, -0.65].map(v -> v / 0.9987));
			for (p in pieces) {
				var placed = Mesh3D.mul(p.model, Mesh3D.translate(p.x, p.y, Meshes3D.Z));
				program.setParameter("mvp", floats(Mesh3D.mul(placed, proj)));
				program.setParameter("model", floats(placed));
				program.setParameter("baseColor", p.color);
				context.setTextureAt(program.textureSlot("image"), p.textured ? texture : null);
				context.setVertexBufferAt(program.inputLocation("position"), p.vertices, 0, Context3DVertexBufferFormat.FLOAT_3);
				context.setVertexBufferAt(program.inputLocation("normal"), p.vertices, 3, Context3DVertexBufferFormat.FLOAT_3);
				context.setVertexBufferAt(program.inputLocation("uv"), p.vertices, 6, Context3DVertexBufferFormat.FLOAT_2);
				context.drawTriangles(p.indices, 0, p.count);
			}
			context.present();
		});

		// The display list draws over the 3D picture.
		var overlay = new Sprite();
		var panel = new Shape();
		panel.graphics.beginFill(0x000000, 0.55);
		panel.graphics.drawRoundRect(0, 0, 150, 26, 8, 8);
		panel.graphics.endFill();
		overlay.addChild(panel);
		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 13, 0xFFFFFF);
		label.selectable = false;
		label.text = "Stage3D + display list";
		label.x = 8;
		label.y = 4;
		label.width = 140;
		overlay.addChild(label);
		overlay.x = 12;
		overlay.y = 10;
		stage.addChild(overlay);
		return app;
	}

	static function main():Void {
		var result = Headless.render("openfl-stage3d-scene", W, H, build, 1.0, 5);
		var failures = [];
		function at(p:{x:Int, y:Int}):Int {
			var i = (p.y * W + p.x) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		var sphere = Meshes3D.project(Meshes3D.LEFT, 0, Meshes3D.Z, W, H);
		var cube = Meshes3D.project(Meshes3D.RIGHT, 0, Meshes3D.Z, W, H);
		var clear = 0x141724;
		if (!created) failures.push("no context was created");
		if (at({x: 460, y: 290}) != clear) failures.push('background ${StringTools.hex(at({x: 460, y: 290}), 6)} not the clear color');
		if (at(sphere) == clear) failures.push("sphere is not drawn");
		if (at(cube) == clear) failures.push("cube is not drawn");
		// The panel's dark fill over the 3D clear color, and its text, are on top.
		var panelPixel = at({x: 20, y: 14});
		if (panelPixel == clear || panelPixel == 0) failures.push('overlay panel ${StringTools.hex(panelPixel, 6)}');
		if (failures.length > 0) throw 'OpenFL Stage3D render wrong: ${failures.join(", ")}';
		Sys.println("OpenFL Stage3D render ok");
	}
}
