package puffpuff.gpu.shaders;

/**
 * Instanced quads with a full color transform, for draws with multipliers above 1 or nonzero offsets. Each instance
 * reads 5 Vec4 rows from `instances`:
 * - row 0: `[a, b, c, d]` (2x2 affine transform)
 * - row 1: `[tx, ty, uvX, uvY]` (translation + top-left UV)
 * - row 2: `[uvW, uvH, alpha, 0]`
 * - row 3: `[red, green, blue, 0]` multipliers
 * - row 4: `[red, green, blue, alpha]` offsets, 0 to 1
 * Color is transformed unpremultiplied and written premultiplied. A shader that `@:extends` this one replaces `fragment()`
 * and can call `flixelTexture2D(uv)` for the transformed texel.
 */
class OffsetQuadShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var projection:Mat4;
		/** 1 when the texture holds premultiplied alpha. **/
		@param var premultiplied:Float;
		@param var bitmap:Sampler2D;
		@param var instances:StorageBuffer<Vec4>;
		var vUv:Vec2;
		var vAlpha:Float;
		var vMultiply:Vec3;
		var vOffset:Vec4;

		function vertex() {
			var corner = vec2(0.0, 0.0);
			if (vertexID == 1 || vertexID == 4) corner = vec2(1.0, 0.0);
			if (vertexID == 2 || vertexID == 3) corner = vec2(0.0, 1.0);
			if (vertexID == 5) corner = vec2(1.0, 1.0);

			var base = instanceID * 5;
			var xform = instances[base];
			var posUv = instances[base + 1];
			var sizeAlpha = instances[base + 2];
			var multiply = instances[base + 3];
			var offset = instances[base + 4];

			var worldPos = vec2(
				xform.x * corner.x + xform.z * corner.y + posUv.x,
				xform.y * corner.x + xform.w * corner.y + posUv.y
			);
			vUv = vec2(posUv.z + corner.x * sizeAlpha.x, posUv.w + corner.y * sizeAlpha.y);
			vAlpha = sizeAlpha.z;
			vMultiply = multiply.xyz;
			vOffset = offset;
			output.position = vec4(worldPos, 0.0, 1.0) * projection;
		}

		/** Bitmap at `uv` with the quad's color transform and alpha applied, premultiplied. Same as Flixel's `flixel_texture2D`. **/
		function flixelTexture2D(uv:Vec2):Vec4 {
			var tex = texture(bitmap, uv);
			var result = vec4(0.0, 0.0, 0.0, 0.0);
			if (tex.a > 0.0) {
				var straight = tex;
				if (premultiplied > 0.5) straight = vec4(tex.rgb / tex.a, tex.a);
				var c = clamp(vOffset + vec4(straight.rgb * vMultiply, straight.a), 0.0, 1.0);
				result = vec4(c.rgb * c.a * vAlpha, c.a * vAlpha);
			}
			return result;
		}

		function fragment() {
			output.color = flixelTexture2D(vUv);
		}
	};
}
