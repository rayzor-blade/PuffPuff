package puffpuff.gpu.shaders;

/**
 * Default untextured 2D graphics shader (positions + per-vertex colors + colour transform).
 */
class GraphicsShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{
			position:Vec2,
			color:Vec4
		};
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var matrix:Mat4;
		@param var colorMultiplier:Vec4;
		@param var colorOffset:Vec4;
		var vColor:Vec4;

		function vertex() {
			vColor = input.color;
			output.position = vec4(input.position, 0.0, 1.0) * matrix;
		}

		function fragment() {
			var c = vColor * colorMultiplier + colorOffset;
			output.color = clamp(c, vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0));
		}
	};
}

