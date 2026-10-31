/** A quad's texture, transformed by the matrix. **/
class TexturedShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{position:Vec3, uv:Vec2};
		var output:{position:Vec4, color:Vec4};
		@param var mvp:Mat4;
		@param var image:Sampler2D;
		var vUv:Vec2;

		function vertex() {
			vUv = input.uv;
			output.position = vec4(input.position, 1.0) * mvp;
		}

		function fragment() {
			output.color = texture(image, vUv);
		}
	};
}
