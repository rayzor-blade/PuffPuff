package puffpuff.gpu.shaders;

/**
 * Instanced quad batch shader for `drawQuads` / `Tilemap` / `FlxCamera` fast-path.
 * Each instance reads 3 Vec4 rows from `instances`:
 * - row 0: `[a, b, c, d]` (2x2 affine transform)
 * - row 1: `[tx, ty, uvX, uvY]` (translation + top-left UV)
 * - row 2: `[uvW, uvH, alpha, tintPacked]` (UV size + alpha + RGBA multiplier)
 */
class InstancedQuadShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var projection:Mat4;
		@param var bitmap:Sampler2D;
		@param var instances:StorageBuffer<Vec4>;
		var vUv:Vec2;
		var vColor:Vec4;

		function vertex() {
			// 6 vertices (2 triangles) per quad: (0,0), (1,0), (0,1), (0,1), (1,0), (1,1)
			var corner = vec2(0.0, 0.0);
			if (vertexID == 1 || vertexID == 4) corner = vec2(1.0, 0.0);
			if (vertexID == 2 || vertexID == 3) corner = vec2(0.0, 1.0);
			if (vertexID == 5) corner = vec2(1.0, 1.0);

			var base = instanceID * 3;
			var xform = instances[base];
			var posUv = instances[base + 1];
			var uvCol = instances[base + 2];

			var worldPos = vec2(
				xform.x * corner.x + xform.z * corner.y + posUv.x,
				xform.y * corner.x + xform.w * corner.y + posUv.y
			);
			vUv = vec2(posUv.z + corner.x * uvCol.x, posUv.w + corner.y * uvCol.y);
			vColor = vec4(1.0, 1.0, 1.0, uvCol.z);
			output.position = vec4(worldPos, 0.0, 1.0) * projection;
		}

		function fragment() {
			output.color = texture(bitmap, vUv) * vColor;
		}
	};
}

