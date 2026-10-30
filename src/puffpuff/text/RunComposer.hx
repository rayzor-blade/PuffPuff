package puffpuff.text;

import puffpuff.gpu.QuadBatcher;
import puffpuff.text.FontAtlas.PreparedGlyph;
import puffpuff.text.FontAtlas.PreparedRun;
import puffpuff.text.GlyphOutlines.TextStyle;

/**
	What one style knows about the printable ASCII characters: advance, glyph bitmap and pair kerning, each taken from
	the native engine the first time it is needed and kept.
**/
class StyleSlot {
	public static inline var FIRST = 32;
	public static inline var COUNT = 95;

	public final family:Null<String>;
	public final generic:Int;
	public final weight:Int;
	public final italic:Bool;
	public final size:Float;
	public final spacing:Float;

	/** Per character from `FIRST`: whether it is known, and 1 when the face draws it. **/
	public final known:Array<Bool> = [for (i in 0...COUNT) false];

	public final usable:Array<Bool> = [for (i in 0...COUNT) false];
	public final advance:Array<Float> = [for (i in 0...COUNT) 0.0];
	public final drawn:Array<Bool> = [for (i in 0...COUNT) false];
	public final gx:Array<Float> = [for (i in 0...COUNT) 0.0];
	public final gy:Array<Float> = [for (i in 0...COUNT) 0.0];
	public final gw:Array<Float> = [for (i in 0...COUNT) 0.0];
	public final gh:Array<Float> = [for (i in 0...COUNT) 0.0];
	public final u0:Array<Float> = [for (i in 0...COUNT) 0.0];
	public final v0:Array<Float> = [for (i in 0...COUNT) 0.0];
	public final u1:Array<Float> = [for (i in 0...COUNT) 0.0];
	public final v1:Array<Float> = [for (i in 0...COUNT) 0.0];

	/** Per ordered pair: 0 unknown, 1 plain (kerning in `kern`), 2 needs the shaper (a ligature, say). **/
	public final pairState:Array<Int> = [for (i in 0...COUNT * COUNT) 0];

	public final kern:Array<Float> = [for (i in 0...COUNT * COUNT) 0.0];

	public var ascent = 0.0;
	public var descent = 0.0;
	public var lineHeight = 0.0;

	public function new(family:Null<String>, generic:Int, weight:Int, italic:Bool, size:Float, spacing:Float) {
		this.family = family;
		this.generic = generic;
		this.weight = weight;
		this.italic = italic;
		this.size = size;
		this.spacing = spacing;
	}

	public inline function matches(family:Null<String>, generic:Int, weight:Int, italic:Bool, size:Float, spacing:Float):Bool
		return this.size == size && this.weight == weight && this.generic == generic && this.italic == italic && this.spacing == spacing
			&& this.family == family;

	public function style():TextStyle
		return {size: size, family: family, generic: generic, weight: weight, italic: italic, letterSpacing: spacing};
}

/**
	Lays out a line of printable ASCII by adding cached per-character data, so a string the engine has not seen costs
	array reads, not shaping. A run that needs the shaper (a ligature or a character outside ASCII) is left to the
	engine: `compose` says no.

	The cache holds atlas rectangles, so it is dropped whenever the native atlases have been cleared (`FontAtlas.generation`).
**/
class RunComposer {
	final atlas:FontAtlas;
	final slots:Array<StyleSlot> = [];
	var generation = -1;

	/** How many times the cache was dropped because the atlas had been cleared. **/
	public var drops(default, null) = 0;

	public function new(atlas:FontAtlas) {
		this.atlas = atlas;
	}

	/** The slot for a style, or null when its text can't be composed. **/
	public function slotFor(size:Float, style:Null<TextStyle>):StyleSlot {
		var family:Null<String> = null;
		var generic = 0;
		var weight = 400;
		var italic = false;
		var spacing = 0.0;
		if (style != null) {
			if (style.size != null) size = style.size;
			family = style.family;
			if (style.generic != null) generic = style.generic;
			if (style.weight != null) weight = style.weight;
			italic = style.italic == true;
			if (style.letterSpacing != null) spacing = style.letterSpacing;
		}
		check();
		for (slot in slots)
			if (slot.matches(family, generic, weight, italic, size, spacing))
				return slot;
		var slot = new StyleSlot(family, generic, weight, italic, size, spacing);
		var run = atlas.prepareNative("M", slot.style());
		slot.ascent = run.ascent;
		slot.descent = run.descent;
		slot.lineHeight = run.lineHeight;
		slots.push(slot);
		return slot;
	}

	/** Drops the cache if the atlases have been cleared since it was filled. **/
	function check():Void {
		var now = atlas.generation;
		if (now == generation)
			return;
		if (slots.length > 0)
			drops++;
		slots.resize(0);
		generation = now;
	}

	function learn(slot:StyleSlot, i:Int):Void {
		var c = String.fromCharCode(StyleSlot.FIRST + i);
		var run = atlas.prepareNative(c, slot.style());
		slot.known[i] = true;
		slot.advance[i] = run.width;
		var expected = c == " " ? 0 : 1;
		slot.usable[i] = run.glyphs.length == expected;
		if (run.glyphs.length > 0) {
			var g = run.glyphs[0];
			slot.drawn[i] = g.width > 0 && g.height > 0 && !g.isColor;
			slot.gx[i] = g.x;
			slot.gy[i] = g.y;
			slot.gw[i] = g.width;
			slot.gh[i] = g.height;
			slot.u0[i] = g.u0;
			slot.v0[i] = g.v0;
			slot.u1[i] = g.u1;
			slot.v1[i] = g.v1;
		}
	}

	function learnPair(slot:StyleSlot, a:Int, b:Int):Void {
		var run = atlas.prepareNative(String.fromCharCode(StyleSlot.FIRST + a) + String.fromCharCode(StyleSlot.FIRST + b), slot.style());
		var expected = (a == 0 ? 0 : 1) + (b == 0 ? 0 : 1);
		var at = a * StyleSlot.COUNT + b;
		if (run.glyphs.length != expected) {
			slot.pairState[at] = 2;
			return;
		}
		slot.kern[at] = run.width - slot.advance[a] - slot.advance[b];
		slot.pairState[at] = 1;
	}

	/** Whether `text` is printable ASCII on one line that the cache can lay out; learns what is missing from it. **/
	public function compose(slot:StyleSlot, text:String):Bool {
		var n = text.length;
		var previous = -1;
		for (k in 0...n) {
			var i = text.charCodeAt(k) - StyleSlot.FIRST;
			if (i < 0 || i >= StyleSlot.COUNT)
				return false;
			if (!slot.known[i])
				learn(slot, i);
			if (!slot.usable[i])
				return false;
			if (previous >= 0) {
				var at = previous * StyleSlot.COUNT + i;
				if (slot.pairState[at] == 0)
					learnPair(slot, previous, i);
				if (slot.pairState[at] == 2)
					return false;
			}
			previous = i;
		}
		return true;
	}

	/** The width of text `compose` accepted. **/
	public function width(slot:StyleSlot, text:String):Float {
		var pen = 0.0;
		var previous = -1;
		for (k in 0...text.length) {
			var i = text.charCodeAt(k) - StyleSlot.FIRST;
			if (previous >= 0)
				pen += slot.kern[previous * StyleSlot.COUNT + i];
			pen += slot.advance[i];
			previous = i;
		}
		return pen;
	}

	/** Queues the glyph quads of text `compose` accepted. Allocates nothing. **/
	public function draw(batcher:QuadBatcher, slot:StyleSlot, text:String, x:Float, y:Float, color:Int, alpha:Float, invW:Float, invH:Float):Void {
		var pen = 0.0;
		var previous = -1;
		for (k in 0...text.length) {
			var i = text.charCodeAt(k) - StyleSlot.FIRST;
			if (previous >= 0)
				pen += slot.kern[previous * StyleSlot.COUNT + i];
			if (slot.drawn[i])
				batcher.addQuad(slot.gw[i], 0.0, 0.0, slot.gh[i], Math.round(x + pen + slot.gx[i]), Math.round(y + slot.gy[i]), slot.u0[i] * invW,
					slot.v0[i] * invH, (slot.u1[i] - slot.u0[i]) * invW, (slot.v1[i] - slot.v0[i]) * invH, alpha, color);
			pen += slot.advance[i];
			previous = i;
		}
	}

	/**
		The advance of each character of text `compose` accepted, with the kerning to the next one folded into it, so
		that the advances add up to `width` and there is one for every character, spaces included.
	**/
	public function advances(slot:StyleSlot, text:String):Array<Float> {
		var out:Array<Float> = [];
		for (k in 0...text.length) {
			var i = text.charCodeAt(k) - StyleSlot.FIRST;
			var next = k + 1 < text.length ? text.charCodeAt(k + 1) - StyleSlot.FIRST : -1;
			out.push(slot.advance[i] + (next >= 0 ? slot.kern[i * StyleSlot.COUNT + next] : 0.0));
		}
		return out;
	}

	/** The run of text `compose` accepted, as the engine would return it. **/
	public function run(slot:StyleSlot, text:String):PreparedRun {
		var glyphs:Array<PreparedGlyph> = [];
		var pen = 0.0;
		var previous = -1;
		for (k in 0...text.length) {
			var i = text.charCodeAt(k) - StyleSlot.FIRST;
			if (previous >= 0)
				pen += slot.kern[previous * StyleSlot.COUNT + i];
			if (slot.drawn[i])
				glyphs.push({
					x: pen + slot.gx[i],
					y: slot.gy[i],
					width: slot.gw[i],
					height: slot.gh[i],
					u0: slot.u0[i],
					v0: slot.v0[i],
					u1: slot.u1[i],
					v1: slot.v1[i],
					isColor: false
				});
			pen += slot.advance[i];
			previous = i;
		}
		return {
			glyphs: glyphs,
			width: pen,
			ascent: slot.ascent,
			descent: slot.descent,
			lineHeight: slot.lineHeight
		};
	}
}
