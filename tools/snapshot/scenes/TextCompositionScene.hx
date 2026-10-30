import lime.math.Matrix4;
import puffpuff.gpu.QuadBatcher;
import puffpuff.snapshot.Snapshot;
import puffpuff.text.FontAtlas;

/**
 * The same lines drawn twice: shaped natively as whole strings (white) and composed from cached per-character data
 * (blue), as `FontAtlas.drawText` does by default. Prints how far the composed glyph positions are from the native ones.
 */
class TextCompositionScene {
	static function main():Void {
		var W = 640, H = 300;
		var style = {size: 14.0, family: "Arimo"};
		var lines = [
			"Label 123: the quick brown fox jumps over the lazy dog",
			"AVATAR To Wa Ty Yo kerning pairs; (parentheses) [brackets]",
			"office fi fl ffi ligature candidates: waffle affix",
			"The quick brown fox jumps over the lazy dog 0123456789"
		];
		var report = [];
		Snapshot.scene("text-composition-scene", W, H, ctx -> {
			var c3 = ctx.wgpu.context3D;
			var atlas = FontAtlas.getDefault(c3);
			var proj = new Matrix4();
			proj.createOrtho(0, W, H, 0, -1, 1);
			var batcher = new QuadBatcher(c3, 2048);
			c3.beginRenderPass(0.06, 0.07, 0.11, 1.0);
			var y = 24.0;
			for (text in lines) {
				atlas.composeRuns = false;
				var native = atlas.prepare(text, style);
				atlas.composeRuns = true;
				var composed = atlas.prepare(text, style);
				var n = Std.int(Math.min(native.glyphs.length, composed.glyphs.length));
				var worst = 0.0, sum = 0.0;
				for (i in 0...n) {
					var d = Math.abs(native.glyphs[i].x - composed.glyphs[i].x);
					worst = Math.max(worst, d);
					sum += d;
				}
				report.push('${StringTools.rpad('"' + text.substr(0, 28) + '"', " ", 34)} glyphs native=${native.glyphs.length} composed=${composed.glyphs.length}  width native=${Math.round(native.width * 100) / 100} composed=${Math.round(composed.width * 100) / 100}  mean |dx|=${Math.round(sum / n * 100) / 100}px worst=${Math.round(worst * 100) / 100}px');

				batcher.begin(atlas.upload(c3));
				atlas.composeRuns = false;
				atlas.drawText(batcher, text, 12, y, 14, 0xFFFFFF, 1.0, style);
				atlas.composeRuns = true;
				atlas.drawText(batcher, text, 12, y + 22, 14, 0x7DD3FC, 1.0, style);
				batcher.flush(proj);
				y += 62;
			}
			c3.endRenderPass();
		}, 0x0F111A);
		for (r in report) Sys.println(r);
	}
}
