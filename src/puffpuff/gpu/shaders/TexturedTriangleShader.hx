package puffpuff.gpu.shaders;

/**
 * Textured triangle list for `Graphics.drawTriangles` and bitmap-filled shapes. A vertex has a position in target pixels,
 * a texture coordinate premultiplied by `t` (the perspective term of `uvtData`, 1 when flat) plus `t` itself, and a color
 * that tints the texture.
 */
class TexturedTriangleShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{
			position:Vec2,
			uvt:Vec3,
			color:Vec4
		};
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var matrix:Mat4;
		/** 1 when the texture is premultiplied, so the tint scales the color too. **/
		@param var premultiplied:Float;
		@param var bitmap:Sampler2D;
		var vUvt:Vec3;
		var vColor:Vec4;

		function vertex() {
			vUvt = input.uvt;
			vColor = input.color;
			output.position = vec4(input.position, 0.0, 1.0) * matrix;
		}

		function fragment() {
			var shaded = texture(bitmap, vUvt.xy / vUvt.z) * vColor;
			if (premultiplied > 0.5)
				shaded = vec4(shaded.rgb * vColor.a, shaded.a);
			output.color = shaded;
		}
	};
}
