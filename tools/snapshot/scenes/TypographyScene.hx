import lime.graphics.Image;
import lime.math.Matrix4;
import lime.text.Font;
import puffpuff.gpu.QuadBatcher;
import puffpuff.snapshot.Snapshot;
import puffpuff.text.FontAtlas;

/**
 * Visual snapshot scene comparing bundled Arimo Sans (variable WOFF2 via `blinc_abi`)
 * and a raw pixel-genre TTF (`fonts/pixel_theme.ttf` -> `SquareFont`) loaded via `Font.fromFile`.
 */
class TypographyScene {
	static function main():Void {
		var width = 800;
		var height = 480;

		var arimo = new Font("Arimo");
		var pixelFont = Font.fromFile("fonts/pixel_theme.ttf", true);

		Snapshot.scene("typography-scene", width, height, ctx -> {
			var ctx3d = ctx.wgpu.context3D;

			var proj = new Matrix4();
			proj.createOrtho(0, width, height, 0, -1, 1);

			ctx3d.beginRenderPass(0.06, 0.07, 0.11, 1.0);

			// 2x2 white pixel texture for panel cards and borders
			var whiteImg = new Image(null, 0, 0, 2, 2, 0xFFFFFFFF);
			var whiteTex = ctx3d.createTexture(2, 2);
			whiteTex.uploadFromImage(whiteImg);

			var batcher = new QuadBatcher(ctx3d, 2048);

			// Panel cards
			batcher.begin(whiteTex);
			// Top card: Arimo Sans (WOFF2 Variable Font)
			batcher.addQuad(752, 0, 0, 204, 24, 20, 0, 0, 1, 1, 1.0, 0x131724);
			// Bottom card: Raw Pixel TTF (SquareFont)
			batcher.addQuad(752, 0, 0, 212, 24, 244, 0, 0, 1, 1, 1.0, 0x161324);
			batcher.flush(proj);

			var atlas = FontAtlas.getDefault(ctx3d);
			batcher.begin(atlas.upload(ctx3d));

			// --- TOP PANEL: Arimo Sans (WOFF2 via blinc_abi) ---
			arimo.drawText(batcher, "1. BUNDLED ARIMO SANS (WOFF2 VARIABLE + SUBPIXEL GAMMA LIFT)", 42, 36, 13.0, 0x38BDF8, 1.0, {weight: 700});
			arimo.drawText(batcher, "PuffPuff Typography Engine", 42, 60, 28.0, 0xF8FAFC, 1.0, {weight: 700});
			arimo.drawText(batcher, "Regular 400: Sphinx of black quartz, judge my vow. (0123456789)", 42, 102, 16.0, 0xE2E8F0, 1.0, {weight: 400});
			arimo.drawText(batcher, "Bold 700: Kerning & shaping via blinc_abi + swash (AVATAR / Wa / To)", 42, 128, 16.0, 0xCBD5E1, 1.0, {weight: 700});
			arimo.drawText(batcher, "Italic 400: True italic face with smooth coverage atlas synchronization", 42, 154, 16.0, 0x94A3B8, 1.0, {italic: true});
			arimo.drawText(batcher, 'Metrics: family="${arimo.name}"  ascender=${arimo.ascender}  descender=${arimo.descender}  upem=${arimo.unitsPerEM}', 42,
				186, 13.0, 0x64748B, 1.0);

			// --- BOTTOM PANEL: Raw Pixel TTF via Font.fromFile ---
			arimo.drawText(batcher,
				'2. RAW PIXEL-GENRE TTF (Font.fromFile -> family="${pixelFont.name}", glyphs=${pixelFont.numGlyphs}, upem=${pixelFont.unitsPerEM})', 42, 260,
				13.0, 0xF59E0B, 1.0, {
					weight: 700
				});

			pixelFont.drawText(batcher, "PIXEL MODE ON (1-BIT THRESHOLD + INTEGER SNAP)", 42, 288, 18.0, 0xFDE047, 1.0, {pixel: true});
			pixelFont.drawText(batcher, "SCORE: 0098450   STAGE: 04-A   CREDITS: 03", 42, 318, 22.0, 0x4ADE80, 1.0, {pixel: true});
			pixelFont.drawText(batcher, "PLAYER 1 READY - INSERT COIN TO CONTINUE!", 42, 352, 28.0, 0xF8FAFC, 1.0, {pixel: true});
			pixelFont.drawText(batcher, "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 !?+-*/", 42, 392, 16.0, 0x38BDF8, 1.0, {pixel: true});
			pixelFont.drawText(batcher, "SMOOTH TTF MODE: ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789", 42, 420, 16.0, 0xA78BFA, 1.0, {pixel: false});

			batcher.flush(proj);

			ctx3d.endRenderPass();
			whiteTex.dispose();
		}, 0x0F111A);
	}
}
