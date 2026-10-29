// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.text;

import lime.math.Vector2;

class TextLayout {
	public var direction:Int = 4; // LTR
	public var font:Font;
	public var glyphs(get, never):Array<Glyph>;
	public var language:String = "en";
	public var positions(get, never):Array<GlyphPosition>;
	public var script:String = "Latn";
	public var size:Int = 16;
	public var text:String = "";

	private var __positions:Array<GlyphPosition> = [];

	public function new(text:String = "", font:Font = null, size:Int = 16, direction:Int = 4, script:String = "Latn", language:String = "en") {
		this.text = text;
		this.font = font;
		this.size = size;
		this.direction = direction;
		this.script = script;
		this.language = language;
		if (text != null && text.length > 0 && font != null) {
			position();
		}
	}

	private function position():Void {
		__positions = [];
		if (font == null || text == null || text.length == 0) return;
		var run = font.getAtlas().prepare(text, {
			family: font.name == "Sans" ? null : font.name,
			size: size * 1.0,
			pixel: font.pixelMode
		});
		for (i in 0...run.glyphs.length) {
			var g = run.glyphs[i];
			var nextX = (i + 1 < run.glyphs.length) ? run.glyphs[i + 1].x : run.width;
			var advX = nextX - g.x;
			var code = i < text.length ? text.charCodeAt(i) : 0;
			__positions.push(new GlyphPosition(new Glyph(code), new Vector2(advX, 0), new Vector2(0, -g.y)));
		}
	}

	private function get_glyphs():Array<Glyph> {
		return [for (p in __positions) p.glyph];
	}

	private inline function get_positions():Array<GlyphPosition> {
		return __positions;
	}
}
