/** A unit quad's texture, placed by a matrix. **/
class QuadShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{position:Vec3, uv:Vec2};
		var output:{position:Vec4, color:Vec4};
		@param var placement:Mat4;
		@param var image:Sampler2D;
		var vUv:Vec2;

		function vertex() {
			vUv = input.uv;
			output.position = vec4(input.position, 1.0) * placement;
		}

		function fragment() {
			output.color = texture(image, vUv);
		}
	};
}
