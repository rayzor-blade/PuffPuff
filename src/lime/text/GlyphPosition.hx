// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.text;

import lime.math.Vector2;

class GlyphPosition {
	public var advance:Vector2;
	public var glyph:Glyph;
	public var offset:Vector2;

	public function new(glyph:Glyph, advance:Vector2, offset:Vector2 = null) {
		this.glyph = glyph;
		this.advance = advance != null ? advance : new Vector2();
		this.offset = offset != null ? offset : new Vector2();
	}
}
