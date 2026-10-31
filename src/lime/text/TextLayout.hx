// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.text;

import lime.math.Vector2;
import puffpuff.text.FontAtlas;

class TextLayout {
	/**
		Whether advances are rounded to whole pixels, as hinted text is. Only honoured when `FontAtlas.hintedAdvances` is
		on, so exact advances stay the default.
	**/
	public var autoHint:Bool = false;
	public var direction:Int = 4; // LTR
	public var font:Font;
	public var glyphs(get, never):Array<Glyph>;
	public var language:String = "en";
	public var positions(get, never):Array<GlyphPosition>;
	public var script:String = "Latn";
	public var size:Int = 16;
	public var text:String = "";

	private var __positions:Array<GlyphPosition> = [];
	private var __computed = false;
	private var __computedText:String;
	private var __computedFont:Font;
	private var __computedSize = 0;
	private var __computedHint = false;

	public function new(text:String = "", font:Font = null, size:Int = 16, direction:Int = 4, script:String = "Latn", language:String = "en") {
		this.text = text;
		this.font = font;
		this.size = size;
		this.direction = direction;
		this.script = script;
		this.language = language;
	}

	private inline function hinted():Bool
		return autoHint && FontAtlas.hintedAdvances;

	private function position():Void {
		__positions = [];
		__computed = true;
		__computedText = text;
		__computedFont = font;
		__computedSize = size;
		__computedHint = hinted();
		if (font == null || text == null || text.length == 0) return;
		// One position per character: the engine knows each character's advance, spaces and ligatures included.
		var advances = font.getAtlas().characterAdvances(text, size * 1.0, {
			family: font.name == "Sans" ? null : font.name,
			pixel: font.pixelMode,
			hinted: __computedHint
		});
		for (i in 0...advances.length) {
			__positions.push(new GlyphPosition(new Glyph(text.charCodeAt(i)), new Vector2(advances[i], 0), new Vector2(0, 0)));
		}
	}

	private function get_glyphs():Array<Glyph> {
		return [for (p in positions) p.glyph];
	}

	private function get_positions():Array<GlyphPosition> {
		// Laid out when asked for, and again when the text, font, size or hinting has changed since.
		if (!__computed || __computedText != text || __computedFont != font || __computedSize != size || __computedHint != hinted()) position();
		return __positions;
	}
}
