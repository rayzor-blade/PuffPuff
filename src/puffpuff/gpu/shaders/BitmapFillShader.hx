package puffpuff.gpu.shaders;

/**
 * Bitmap fill shader for `Graphics.beginBitmapFill` (positions + UVs + projection matrix).
 */
class BitmapFillShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{
			position:Vec2,
			uv:Vec2
		};
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var matrix:Mat4;
		@param var bitmap:Sampler2D;
		var vUv:Vec2;

		function vertex() {
			vUv = input.uv;
			output.position = vec4(input.position, 0.0, 1.0) * matrix;
		}

		function fragment() {
			output.color = texture(bitmap, vUv);
		}
	};
}
