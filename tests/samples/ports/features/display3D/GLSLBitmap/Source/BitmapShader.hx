/** A bitmap placed by a matrix. **/
class BitmapShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{position:Vec3, texCoord:Vec2};
		var output:{position:Vec4, color:Vec4};
		@param var matrix:Mat4;
		@param var image:Sampler2D;
		var vTexCoord:Vec2;

		function vertex() {
			vTexCoord = input.texCoord;
			output.position = vec4(input.position, 1.0) * matrix;
		}

		function fragment() {
			output.color = texture(image, vTexCoord);
		}
	};
}
