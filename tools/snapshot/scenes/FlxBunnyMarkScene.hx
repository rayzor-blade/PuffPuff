import haxe.io.Bytes;
import lime.graphics.Image;
import lime.graphics.Image.ImageBuffer;
import lime.math.Matrix4;
import lime.text.Font;
import puffpuff.gpu.QuadBatcher;
import puffpuff.gpu.WgpuContext3D.WgpuTexture;
import puffpuff.snapshot.Snapshot;

/**
 * Phase 4 Snapshot Conformance Scene:
 * Renders a deterministic 500-sprite BunnyMark scene + HUD overlay using `QuadBatcher` (instanced `drawQuads` fast-path)
 * and `FontAtlas` (`lime.text.Font` glyph rendering) in 2 GPU draw calls.
 */
class FlxBunnyMarkScene {
	static function createBunnySpriteTexture():Image {
		var w = 32;
		var h = 32;
		var bytes = Bytes.alloc(w * h * 4);
		for (y in 0...h) {
			for (x in 0...w) {
				var idx = (y * w + x) * 4;
				var dx = (x - 15.5) / 11.0;
				var dy = (y - 19.5) / 10.0;
				var body = dx * dx + dy * dy <= 1.0;

				var earL = ((x - 10.5) / 3.2) * ((x - 10.5) / 3.2) + ((y - 8.0) / 7.5) * ((y - 8.0) / 7.5) <= 1.0;
				var earR = ((x - 20.5) / 3.2) * ((x - 20.5) / 3.2) + ((y - 8.0) / 7.5) * ((y - 8.0) / 7.5) <= 1.0;

				var eyeL = (x >= 11 && x <= 13 && y >= 16 && y <= 18);
				var eyeR = (x >= 18 && x <= 20 && y >= 16 && y <= 18);

				if (eyeL || eyeR) {
					bytes.set(idx, 25);
					bytes.set(idx + 1, 25);
					bytes.set(idx + 2, 35);
					bytes.set(idx + 3, 255);
				} else if (body || earL || earR) {
					bytes.set(idx, 255);
					bytes.set(idx + 1, 255);
					bytes.set(idx + 2, 255);
					bytes.set(idx + 3, 255);
				}
			}
		}
		return new Image(new ImageBuffer(bytes, w, h, 32, 0), 0, 0, w, h);
	}

	static function main() {
		var w = 640;
		var h = 360;
		var bunnyCount = 500;
		var palette = [0xFF6B6B, 0x4ECDC4, 0xFFE66D, 0xA8E6CF, 0xFF8B94, 0x74B9FF, 0xA29BFE];

		Snapshot.scene("flx-bunnymark-scene", w, h, ctx -> {
			var c3d = ctx.wgpu.context3D;
			c3d.smoothing = false;

			var proj = new Matrix4();
			proj.createOrtho(0, w, h, 0, -1, 1);

			c3d.beginRenderPass(0.07, 0.08, 0.13, 1.0);

			var bunnyImg = createBunnySpriteTexture();
			var bunnyTex:WgpuTexture = c3d.createTexture(bunnyImg.width, bunnyImg.height);
			bunnyTex.uploadFromImage(bunnyImg);

			var batcher = new QuadBatcher(c3d, 1024);

			// 1. Batch 500 tinted, rotated, scaled sprites in 1 instanced draw call
			batcher.begin(bunnyTex);
			var seed = 1337;
			for (i in 0...bunnyCount) {
				seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
				var bx = 24.0 + (seed % (w - 72));
				seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
				var by = 52.0 + (seed % (h - 88));
				seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
				var angle = ((seed % 1000) / 1000.0 - 0.5) * 0.6;
				var size = 22.0 + (i % 14);
				var cos = Math.cos(angle) * size;
				var sin = Math.sin(angle) * size;
				var tint = palette[i % palette.length];

				batcher.addQuad(
					cos, sin, -sin, cos,
					bx, by,
					0.0, 0.0, 1.0, 1.0,
					0.92, tint
				);
			}
			batcher.flush(proj);

			// 2. Render FlxText HUD banner using FontAtlas in 1 instanced draw call
			var font = new Font("PuffSans");
			var atlas = font.getAtlas(c3d);
			batcher.begin(atlas.texture);
			atlas.drawText(batcher, "PUFFPUFF WGPU + HXSL BACKEND", 20, 14, 16, 0xFFE66D, 1.0);
			atlas.drawText(batcher, 'INSTANCED DRAWQUADS: $bunnyCount SPRITES (1 DRAW CALL)', 20, 34, 12, 0x4ECDC4, 1.0);
			batcher.flush(proj);

			c3d.endRenderPass();
			bunnyTex.dispose();
		}, 0x121421);
	}
}
