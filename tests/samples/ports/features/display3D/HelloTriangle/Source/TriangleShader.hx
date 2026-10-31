/** A triangle with a color at each corner, spun by the matrix. **/
class TriangleShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{position:Vec3, color:Vec3};
		var output:{position:Vec4, color:Vec4};
		@param var mvp:Mat4;
		var vColor:Vec3;

		function vertex() {
			vColor = input.color;
			output.position = vec4(input.position, 1.0) * mvp;
		}

		function fragment() {
			output.color = vec4(vColor, 1.0);
		}
	};
}
