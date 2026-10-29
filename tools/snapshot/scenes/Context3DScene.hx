import gpu.VertexFormat;
import haxe.io.Bytes;
import lime.math.Matrix4;
import lime.utils.Float32Array;
import puffpuff.snapshot.Snapshot;

/**
 * Snapshot scene testing WgpuContext3D, PipelineCache, HXSL stock shaders
 * (GraphicsShader, DisplayObjectShader, InstancedQuadShader), VertexBuffer3D, IndexBuffer3D, and WgpuTexture.
 */
class Context3DScene {
	static function createCheckerTextureBytes(size:Int):Bytes {
		var bytes = Bytes.alloc(size * size * 4);
		for (y in 0...size) {
			for (x in 0...size) {
				var idx = (y * size + x) * 4;
				var cell = ((x >> 3) + (y >> 3)) & 1;
				if (cell == 0) {
					bytes.set(idx, 255);
					bytes.set(idx + 1, 215);
					bytes.set(idx + 2, 70);
					bytes.set(idx + 3, 255);
				} else {
					bytes.set(idx, 55);
					bytes.set(idx + 1, 140);
					bytes.set(idx + 2, 245);
					bytes.set(idx + 3, 255);
				}
			}
		}
		return bytes;
	}

	static function main() {
		var w = 640;
		var h = 360;

		Snapshot.scene("context3d-scene", w, h, ctx -> {
			var c3d = ctx.wgpu.context3D;
			var proj = new Matrix4();
			proj.createOrtho(0, w, h, 0, -1, 1);

			c3d.beginRenderPass(0.08, 0.09, 0.14, 1.0);

			// 1. Untextured GraphicsShader quad (left card)
			// 6 floats per vertex: [x, y, r, g, b, a]
			var vbUntex = c3d.createVertexBuffer(4, 6);
			vbUntex.uploadFromFloat32Array(new Float32Array([
				 40.0,  60.0, 0.95, 0.30, 0.45, 1.0,
				200.0,  60.0, 0.98, 0.65, 0.25, 1.0,
				200.0, 300.0, 0.55, 0.25, 0.90, 1.0,
				 40.0, 300.0, 0.20, 0.80, 0.75, 1.0
			]));
			var ib = c3d.createIndexBuffer(6);
			ib.uploadFromArray([0, 1, 2, 0, 2, 3]);

			c3d.setTextureAt(0, null);
			c3d.setVertexBufferAt(0, vbUntex, 0, VertexFormat.Float32x2);
			c3d.setVertexBufferAt(1, vbUntex, 2, VertexFormat.Float32x4);
			c3d.drawTriangles(ib, proj);

			// 2. Textured DisplayObjectShader quad (middle card)
			// 8 floats per vertex: [x, y, u, v, r, g, b, a]
			var tex = c3d.createTexture(64, 64);
			tex.uploadFromBytes(createCheckerTextureBytes(64));

			var vbTex = c3d.createVertexBuffer(4, 8);
			vbTex.uploadFromFloat32Array(new Float32Array([
				240.0,  60.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0,
				400.0,  60.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0,
				400.0, 300.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
				240.0, 300.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0
			]));

			c3d.smoothing = false;
			c3d.setTextureAt(0, tex);
			c3d.setVertexBufferAt(0, vbTex, 0, VertexFormat.Float32x2);
			c3d.setVertexBufferAt(1, vbTex, 2, VertexFormat.Float32x2);
			c3d.setVertexBufferAt(2, vbTex, 4, VertexFormat.Float32x4);
			c3d.drawTriangles(ib, proj);

			// 3. Instanced drawQuads fast-path (right panel: 4 rotated/scaled sprites in 1 draw call)
			var quadCount = 4;
			var instData = new Float32Array(quadCount * 12);
			for (i in 0...quadCount) {
				var angle = i * 0.28;
				var scale = 68.0 - i * 8.0;
				var cos = Math.cos(angle) * scale;
				var sin = Math.sin(angle) * scale;
				var base = i * 12;
				// row 0: [a, b, c, d]
				instData[base + 0] = cos;
				instData[base + 1] = sin;
				instData[base + 2] = -sin;
				instData[base + 3] = cos;
				// row 1: [tx, ty, uvX, uvY]
				instData[base + 4] = 475.0 + (i % 2) * 65.0;
				instData[base + 5] = 85.0 + Std.int(i / 2) * 115.0;
				instData[base + 6] = 0.0;
				instData[base + 7] = 0.0;
				// row 2: [uvW, uvH, alpha, 0]
				instData[base + 8] = 1.0;
				instData[base + 9] = 1.0;
				instData[base + 10] = 1.0 - i * 0.12;
				instData[base + 11] = 0.0;
			}
			c3d.drawQuadsInstanced(tex, proj, instData, quadCount);

			c3d.endRenderPass();

			vbUntex.dispose();
			vbTex.dispose();
			ib.dispose();
			tex.dispose();
		}, 0x141724);
	}
}
