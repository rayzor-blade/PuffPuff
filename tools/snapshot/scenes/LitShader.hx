/**
 * Lambert and Blinn-Phong light from one directional light on a mesh with normals and UVs, over a texture and a base color.
 */
class LitShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{position:Vec3, normal:Vec3, uv:Vec2};
		var output:{position:Vec4, color:Vec4};
		@param var mvp:Mat4;
		/** Rotation of the mesh, for its normals. **/
		@param var model:Mat4;
		/** Unit vector from the surface toward the light. **/
		@param var lightDir:Vec3;
		@param var baseColor:Vec4;
		@param var image:Sampler2D;
		var vNormal:Vec3;
		var vUv:Vec2;

		function vertex() {
			vNormal = (vec4(input.normal, 0.0) * model).xyz;
			vUv = input.uv;
			output.position = vec4(input.position, 1.0) * mvp;
		}

		function fragment() {
			var n = normalize(vNormal);
			var diffuse = max(dot(n, lightDir), 0.0);
			var half = normalize(lightDir + vec3(0.0, 0.0, -1.0));
			var spec = pow(max(dot(n, half), 0.0), 40.0);
			var albedo = texture(image, vUv) * baseColor;
			output.color = vec4(albedo.rgb * (0.3 + 0.7 * diffuse) + vec3(spec * 0.35), albedo.a);
		}
	};
}
