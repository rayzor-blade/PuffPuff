package puffpuff.gpu.shaders;

/**
 * One separable Gaussian pass over `source`, full-screen triangle (no vertex buffer).
 * `effect.xy` = step per tap in UV (texel size × direction × spread).
 *
 * 9-tap σ≈2 kernel folded into 5 fetches via bilinear tap pairing: each adjacent pair
 * `(w_i, w_{i+1})` is one linear fetch at `i + w_{i+1} / (w_i + w_{i+1})` with weight `w_i + w_{i+1}`.
 * Requires a linear-filtering sampler.
 */
class BlurShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var effect:Vec4;
		@param var source:Sampler2D;
		var uv:Vec2;

		function vertex() {
			// Oversized triangle covering the viewport: (-1,-1), (3,-1), (-1,3).
			var c = vec2(-1.0, -1.0);
			if (vertexID == 1)
				c = vec2(3.0, -1.0);
			if (vertexID == 2)
				c = vec2(-1.0, 3.0);
			uv = vec2(c.x * 0.5 + 0.5, 0.5 - c.y * 0.5);
			output.position = vec4(c, 0.0, 1.0);
		}

		function fragment() {
			var s = effect.xy;
			var sum = textureLod(source, uv, 0.0) * 0.2270270270;
			sum += textureLod(source, uv + s * 1.3846153846, 0.0) * 0.3162162162;
			sum += textureLod(source, uv - s * 1.3846153846, 0.0) * 0.3162162162;
			sum += textureLod(source, uv + s * 3.2307692308, 0.0) * 0.0702702703;
			sum += textureLod(source, uv - s * 3.2307692308, 0.0) * 0.0702702703;
			output.color = sum;
		}
	};
}

