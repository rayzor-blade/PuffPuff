import gpu.CompareFunction;
import gpu.CullMode;
import gpu.VertexFormat;
import haxe.io.Bytes;
import lime.utils.Float32Array;
import puffpuff.gpu.HxslProgram;
import puffpuff.gpu.WgpuContext3D;

/**
 * A lit torus with a sphere in its hole, and a textured cube, drawn with an HXSL program through a perspective camera.
 * Back faces are culled and the depth buffer sorts the pieces that cross. Needs `depthEnabled` and a depth clear when
 * the pass begins.
 */
class Meshes3D {
	public static inline var FOV = 0.6;
	/** Distance of the meshes from the camera, and where the torus and the cube sit across. **/
	public static inline var Z = 7.0;
	public static inline var LEFT = -1.6;
	public static inline var RIGHT = 1.6;

	static var light = {
		var v = [-0.5, 0.6, -0.65];
		var len = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
		[v[0] / len, v[1] / len, v[2] / len];
	};

	/** Matrix that puts clip space into a band of the target: `top` and `height` as fractions of its height. **/
	public static function band(top:Float, height:Float):Float32Array {
		var m = Mesh3D.identity();
		m[5] = height;
		m[7] = 1 - top * 2 - height;
		return m;
	}

	/** Pixel a point in front of the camera lands on, in a band `width` by `height`. **/
	public static function project(x:Float, y:Float, z:Float, width:Int, height:Int) {
		var f = 1 / Math.tan(FOV / 2);
		return {x: Std.int((x * f / (width / height) / z + 1) / 2 * width), y: Std.int((1 - y * f / z) / 2 * height)};
	}

	static function checker():Bytes {
		var bytes = Bytes.alloc(64 * 64 * 4);
		for (y in 0...64)
			for (x in 0...64) {
				var on = ((x >> 3) + (y >> 3)) & 1 == 0;
				var at = (y * 64 + x) * 4;
				bytes.set(at, on ? 245 : 70);
				bytes.set(at + 1, on ? 215 : 120);
				bytes.set(at + 2, on ? 90 : 235);
				bytes.set(at + 3, 255);
			}
		return bytes;
	}

	/** Draws the meshes, turned by `angle`, for a camera whose picture is `aspect` wide, into `placement` if given. **/
	public static function draw(c3d:WgpuContext3D, angle:Float, aspect:Float, placement:Float32Array = null):Void {
		c3d.setDepthTest(true, CompareFunction.Less);
		c3d.setCulling(CullMode.Back);

		var proj = Mesh3D.perspective(FOV, aspect, 0.5, 20);
		if (placement != null) proj = Mesh3D.mul(proj, placement);

		var program = HxslProgram.of(LitShader);
		c3d.program = program;
		var texture = c3d.createTexture(64, 64);
		texture.uploadFromBytes(checker());

		function mesh(m:Mesh3D, model:Float32Array, x:Float, y:Float, z:Float, color:Array<Float>, textured:Bool):Void {
			var vb = c3d.createVertexBuffer(Std.int(m.vertices.length / 8), 8);
			vb.uploadFromFloat32Array(m.vertices);
			var ib = c3d.createIndexBuffer(m.indices.length);
			ib.uploadFromArray(m.indices);
			var world = Mesh3D.mul(model, Mesh3D.translate(x, y, z));
			program.setRaw("mvp", Mesh3D.mul(world, proj));
			program.setRaw("model", world);
			program.setFloats("lightDir", light);
			program.setFloats("baseColor", color);
			c3d.setTextureAt(program.textureSlot("image"), textured ? texture : null);
			c3d.setVertexBufferAt(program.inputLocation("position"), vb, 0, VertexFormat.Float32x3);
			c3d.setVertexBufferAt(program.inputLocation("normal"), vb, 3, VertexFormat.Float32x3);
			c3d.setVertexBufferAt(program.inputLocation("uv"), vb, 6, VertexFormat.Float32x2);
			c3d.drawProgram(ib);
		}

		mesh(Mesh3D.torus(1.0, 0.3, 48, 24), Mesh3D.mul(Mesh3D.rotateX(1.0), Mesh3D.rotateY(angle)), LEFT, 0, Z, [1.0, 0.55, 0.2, 1.0], false);
		mesh(Mesh3D.sphere(0.5, 24, 32), Mesh3D.identity(), LEFT, 0, Z, [0.25, 0.8, 0.75, 1.0], false);
		mesh(Mesh3D.cube(0.8), Mesh3D.mul(Mesh3D.rotateY(angle + 0.6), Mesh3D.rotateX(0.35)), RIGHT, 0, Z, [1.0, 1.0, 1.0, 1.0], true);

		c3d.setCulling(CullMode.None);
		c3d.setDepthTest(false, CompareFunction.Always);
		c3d.program = null;
	}
}
