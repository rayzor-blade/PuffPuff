import lime.math.Matrix4;
import lime.text.Font;
import puffpuff.canvas.Affine;
import puffpuff.canvas.Canvas2D;
import puffpuff.canvas.Paint;
import puffpuff.canvas.Path;
import puffpuff.canvas.Stroke;
import puffpuff.gpu.QuadBatcher;
import puffpuff.gpu.effects.PostEffects;
import puffpuff.snapshot.Snapshot;
import puffpuff.text.FontAtlas;

/**
 * Visual snapshot of `puffpuff.canvas.Canvas2D` (analytic-AA fills, strokes, gradients, dashes,
 * fill rules, SVG paths, translation-cache reuse) and `PostEffects` (Gaussian blur, dual-Kawase bloom).
 */
class Canvas2DScene {
	static inline var W = 860;
	static inline var H = 540;
	static inline var PW = 280;
	static inline var PH = 200;

	static function star(cx:Float, cy:Float, r:Float):Path {
		var p = new Path();
		for (i in 0...5) {
			var k = (i * 2) % 5;
			var a = -Math.PI / 2 + k * Math.PI * 2 / 5;
			var x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r;
			if (i == 0)
				p.moveTo(x, y)
			else
				p.lineTo(x, y);
		}
		return p.close();
	}

	static function ortho(w:Float, h:Float):Matrix4 {
		var m = new Matrix4();
		m.createOrtho(0, w, h, 0, -1, 1);
		return m;
	}

	static function main():Void {
		var arimo = new Font("Arimo");
		var heart = Path.svg("M 0 -6 C -4 -12 -14 -8 -10 0 L 0 10 L 10 0 C 14 -8 4 -12 0 -6 Z");

		Snapshot.scene("canvas2d-scene", W, H, ctx -> {
			var c3 = ctx.wgpu.context3D;
			var fx = new PostEffects(c3);

			// --- Offscreen: blur source ---
			var blurSrc = c3.createTexture(PW, PH);
			var blurDst = c3.createTexture(PW, PH);
			var cb = new Canvas2D(c3);
			cb.begin();
			cb.fill(new Path().rect(0, 0, PW, PH), Paint.solid(0x1E293B));
			cb.fill(new Path().roundedRect(30, 30, 120, 80, 14), Paint.solid(0xF472B6));
			cb.fill(new Path().circle(190, 120, 50), Paint.solid(0x38BDF8));
			cb.stroke(new Path().moveTo(20, 170).lineTo(260, 150), new Stroke(6, Round), Paint.solid(0xFDE047));
			c3.setRenderToTexture(blurSrc);
			c3.beginRenderPass(0, 0, 0, 1);
			cb.flush(ortho(PW, PH));
			c3.endRenderPass();
			fx.blur(blurSrc, blurDst, 6);

			// --- Offscreen: bloom source (neon on near-black) ---
			var bloomSrc = c3.createTexture(PW, PH);
			var bloomDst = c3.createTexture(PW, PH);
			var cn = new Canvas2D(c3);
			cn.begin();
			cn.fill(new Path().rect(0, 0, PW, PH), Paint.solid(0x05060A));
			cn.stroke(new Path().roundedRect(24, 24, PW - 48, PH - 48, 22), new Stroke(4), Paint.solid(0x22D3EE));
			cn.stroke(star(PW / 2, PH / 2, 56), new Stroke(3.5, Round, Round), Paint.solid(0xF0ABFC));
			cn.fill(new Path().circle(PW / 2, PH / 2, 10), Paint.solid(0xFFFFFF));
			c3.setRenderToTexture(bloomSrc);
			c3.beginRenderPass(0, 0, 0, 1);
			cn.flush(ortho(PW, PH));
			c3.endRenderPass();
			fx.bloom(bloomSrc, bloomDst, 0.35, 1.6);

			// --- On screen ---
			c3.setRenderToBackBuffer();
			c3.beginRenderPass(0.06, 0.07, 0.11, 1.0);
			var proj = ortho(W, H);

			var cv = new Canvas2D(c3);
			cv.trackHits = true;
			cv.begin();

			// Gradient card with hairline rim.
			var card = new Path().roundedRect(30, 40, 220, 130, 18);
			cv.fill(card, Paint.linear(30, 40, 250, 170, [{offset: 0, rgb: 0x6366F1, alpha: 1}, {offset: 1, rgb: 0xEC4899, alpha: 1}]));
			cv.stroke(card, new Stroke(1), Paint.solid(0xFFFFFF, 0.35));

			// Radial gradient sphere.
			cv.fill(new Path().circle(380, 105, 65), Paint.radial(360, 85, 80, [
				{offset: 0, rgb: 0xFEF3C7, alpha: 1},
				{offset: 0.45, rgb: 0xF59E0B, alpha: 1},
				{offset: 1, rgb: 0x7C2D12, alpha: 1}
			]));

			// Fill rules: NonZero fills the pentagram core, EvenOdd leaves it hollow.
			cv.fill(star(95, 260, 60), Paint.solid(0x34D399), NonZero);
			cv.fill(star(235, 260, 60), Paint.solid(0x34D399), EvenOdd);

			// Translucent overlap.
			cv.fill(new Path().circle(355, 245, 42), Paint.solid(0xEF4444, 0.6));
			cv.fill(new Path().circle(395, 245, 42), Paint.solid(0x22C55E, 0.6));
			cv.fill(new Path().circle(375, 280, 42), Paint.solid(0x3B82F6, 0.6));

			// Caps: Butt / Round / Square.
			var caps = [Butt, Round, Square];
			for (i in 0...3)
				cv.stroke(new Path().moveTo(40, 350 + i * 22).lineTo(150, 350 + i * 22), new Stroke(12, caps[i]), Paint.solid(0xE2E8F0));

			// Joins: Miter / Round / Bevel.
			var joins:Array<puffpuff.canvas.Stroke.LineJoin> = [Miter, Round, Bevel];
			for (i in 0...3) {
				var x0 = 185 + i * 75;
				cv.stroke(new Path().moveTo(x0, 395).lineTo(x0 + 25, 345).lineTo(x0 + 50, 395), new Stroke(10, Butt, joins[i]), Paint.solid(0xA78BFA));
			}

			// Cubic wave + dashed rounded rect.
			cv.stroke(new Path().moveTo(40, 450).cubicTo(110, 400, 150, 500, 220, 450).cubicTo(290, 400, 330, 500, 420, 450), new Stroke(3, Round),
				Paint.linear(40, 0, 420, 0, [
					{
						offset: 0,
						rgb: 0x22D3EE,
						alpha: 1
					},
					{offset: 1, rgb: 0xF472B6, alpha: 1}
				]));
			cv.stroke(new Path().roundedRect(30, 480, 400, 44, 12), new Stroke(1.5, Butt, Miter, 4, [8, 5]), Paint.solid(0x94A3B8));

			// SVG heart ×3 at the same scale: 3rd draw replays cached triangles shifted.
			for (i in 0...3)
				cv.fill(heart, Paint.solid(0xF43F5E), NonZero, new Affine(3.2, 0, 0, 3.2, 300 + i * 0, 0).after(Affine.translation(i * 14, 112)));

			// Hairlines and a rotated square.
			for (i in 0...4)
				cv.stroke(new Path().moveTo(455, 330 + i * 12).lineTo(505, 318 + i * 12), new Stroke(0.5 + i * 0.5), Paint.solid(0xCBD5E1));
			cv.fill(new Path().rect(-18, -18, 36, 36), Paint.solid(0xFBBF24), NonZero, Affine.translation(480, 430).after(Affine.rotation(Math.PI / 7)));

			cv.flush(proj);

			// Effect panels.
			var quads = new QuadBatcher(c3, 16);
			quads.begin(blurSrc);
			quads.addQuad(PW / 2, 0, 0, PH / 2, 540, 40);
			quads.flush(proj);
			quads.begin(blurDst);
			quads.addQuad(PW / 2, 0, 0, PH / 2, 690, 40);
			quads.flush(proj);
			quads.begin(bloomSrc);
			quads.addQuad(PW / 2, 0, 0, PH / 2, 540, 300);
			quads.flush(proj);
			quads.begin(bloomDst);
			quads.addQuad(PW, 0, 0, PH, 540, 320 - 0);
			quads.flush(proj);

			var atlas = FontAtlas.getDefault(c3);
			var text = new QuadBatcher(c3, 1024);
			text.begin(atlas.upload(c3));
			arimo.drawText(text, "CANVAS2D — ANALYTIC AA VECTORS", 30, 14, 13.0, 0x38BDF8, 1.0, {weight: 700});
			arimo.drawText(text, "NonZero", 70, 330, 12.0, 0x94A3B8);
			arimo.drawText(text, "EvenOdd", 210, 330, 12.0, 0x94A3B8);
			arimo.drawText(text, "GAUSSIAN BLUR (σ=6, TAP-PAIRED)", 540, 14, 13.0, 0x38BDF8, 1.0, {weight: 700});
			arimo.drawText(text, "source", 540, 146, 12.0, 0x94A3B8);
			arimo.drawText(text, "blurred", 690, 146, 12.0, 0x94A3B8);
			arimo.drawText(text, "DUAL-KAWASE BLOOM", 540, 274, 13.0, 0x38BDF8, 1.0, {weight: 700});
			var hit = cv.hitTest(380, 105);
			arimo.drawText(text, 'draws=${cv.drawCount} verts=${cv.vertexCount} reused=${cv.reused} hit(380,105)=${hit}', 455, 290, 11.0, 0x64748B);
			text.flush(proj);

			c3.endRenderPass();
		}, 0x0F111A);
	}
}
