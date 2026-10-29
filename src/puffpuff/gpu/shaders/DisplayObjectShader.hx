package puffpuff.gpu.shaders;

/**
 * Default OpenFL DisplayObject / Bitmap / Tilemap shader (positions, UVs, vertex color, texture, and color transform).
 */
class DisplayObjectShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{
			position:Vec2,
			uv:Vec2,
			color:Vec4
		};
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var matrix:Mat4;
		@param var colorMultiplier:Vec4;
		@param var colorOffset:Vec4;
		@param var bitmap:Sampler2D;
		var vUv:Vec2;
		var vColor:Vec4;

		function vertex() {
			vUv = input.uv;
			vColor = input.color;
			output.position = vec4(input.position, 0.0, 1.0) * matrix;
		}

		function fragment() {
			var tex = texture(bitmap, vUv);
			var c = tex * vColor * colorMultiplier + colorOffset;
			output.color = clamp(c, vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0));
		}
	};
}

