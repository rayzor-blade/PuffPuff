package puffpuff.gpu.shaders;

/**
 * Dual-Kawase bloom steps, one full-screen pass each. `effect = (texelX, texelY, step, value)`:
 *   0 threshold — half-res prefilter keeping what exceeds `value` with a soft knee; each of the
 *     4 taps is Karis-weighted `1 / (1 + luma)` so a lone hot pixel cannot flicker.
 *   1 down — dual-Kawase downsample (5 taps).
 *   2 up — dual-Kawase upsample (8 taps), blended additively onto the next larger level.
 *   3 copy — `source × value`; blended additively it composites the bloom.
 * The pyramid spreads light widely at a cost independent of radius.
 */
class BloomShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var effect:Vec4;
		@param var source:Sampler2D;
		var uv:Vec2;

		function vertex() {
			var c = vec2(-1.0, -1.0);
			if (vertexID == 1)
				c = vec2(3.0, -1.0);
			if (vertexID == 2)
				c = vec2(-1.0, 3.0);
			uv = vec2(c.x * 0.5 + 0.5, 0.5 - c.y * 0.5);
			output.position = vec4(c, 0.0, 1.0);
		}

		function tap(at:Vec2):Vec3 {
			return textureLod(source, at, 0.0).rgb;
		}

		function bright(c:Vec3, threshold:Float):Vec3 {
			var level = max(c.r, max(c.g, c.b));
			var knee = threshold * 0.5;
			var soft = clamp(level - threshold + knee, 0.0, 2.0 * knee);
			soft = soft * soft / (4.0 * knee + 0.00001);
			var kept = max(soft, level - threshold) / max(level, 0.00001);
			return c * kept;
		}

		function fragment() {
			var t = effect.xy;
			var step = effect.z;
			var result = vec3(0.0, 0.0, 0.0);
			if (step < 0.5) {
				var a = bright(tap(uv + t * vec2(-1.0, -1.0)), effect.w);
				var b = bright(tap(uv + t * vec2(1.0, -1.0)), effect.w);
				var c = bright(tap(uv + t * vec2(-1.0, 1.0)), effect.w);
				var d = bright(tap(uv + t * vec2(1.0, 1.0)), effect.w);
				var wa = 1.0 / (1.0 + max(a.r, max(a.g, a.b)));
				var wb = 1.0 / (1.0 + max(b.r, max(b.g, b.b)));
				var wc = 1.0 / (1.0 + max(c.r, max(c.g, c.b)));
				var wd = 1.0 / (1.0 + max(d.r, max(d.g, d.b)));
				result = (a * wa + b * wb + c * wc + d * wd) / (wa + wb + wc + wd);
			} else if (step < 1.5) {
				result = (tap(uv) * 4.0
					+ tap(uv + t * vec2(-1.0, -1.0))
					+ tap(uv + t * vec2(1.0, -1.0))
					+ tap(uv + t * vec2(-1.0, 1.0))
					+ tap(uv + t * vec2(1.0, 1.0))) / 8.0;
			} else if (step < 2.5) {
				result = (tap(uv + t * vec2(-2.0, 0.0))
					+ tap(uv + t * vec2(2.0, 0.0))
					+ tap(uv + t * vec2(0.0, -2.0))
					+ tap(uv + t * vec2(0.0, 2.0))
					+ (tap(uv + t * vec2(-1.0, -1.0)) + tap(uv + t * vec2(1.0, -1.0)) + tap(uv + t * vec2(-1.0, 1.0)) + tap(uv + t * vec2(1.0, 1.0))) * 2.0) / 12.0;
			} else {
				result = tap(uv) * effect.w;
			}
			output.color = vec4(result, 1.0);
		}
	};
}

