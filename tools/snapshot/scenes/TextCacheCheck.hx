import puffpuff.text.FontAtlas;

/**
 * Checks that lines composed from cached units come out as shaping them whole does, for Latin, accents, ligature
 * candidates, CJK, symbols, emoji and Arabic, and that the cache follows an atlas clear. Prints
 * "text cache checks passed" or throws.
 */
class TextCacheCheck {
	static function fail(message:String):Void {
		throw 'text cache check failed: $message';
	}

	static function lay(atlas:FontAtlas, text:String, style:Dynamic, whole:Bool):puffpuff.text.FontAtlas.PreparedRun {
		FontAtlas.wordCache(!whole);
		var run = atlas.prepare(text, style);
		FontAtlas.wordCache(true);
		return run;
	}

	/** Same glyph count, width within `width` px, each glyph's x within `place` px and its bitmap the same size. **/
	static function agree(atlas:FontAtlas, text:String, style:Dynamic, width:Float, place:Float):Void {
		var reference = lay(atlas, text, style, true);
		var composed = lay(atlas, text, style, false);
		var label = '"${text.substr(0, 24)}"';
		if (composed.glyphs.length != reference.glyphs.length) fail('$label: ${composed.glyphs.length} glyphs, whole line ${reference.glyphs.length}');
		if (Math.abs(composed.width - reference.width) > width) fail('$label: width ${composed.width}, whole line ${reference.width}');
		for (i in 0...reference.glyphs.length) {
			var a = composed.glyphs[i], b = reference.glyphs[i];
			if (Math.abs(a.x - b.x) > place) fail('$label: glyph $i at ${a.x}, whole line ${b.x}');
			if (Math.abs(a.y - b.y) > 0.01) fail('$label: glyph $i at y ${a.y}, whole line ${b.y}');
			if (Math.abs((a.u1 - a.u0) - (b.u1 - b.u0)) > 0.01 || Math.abs((a.v1 - a.v0) - (b.v1 - b.v0)) > 0.01) fail('$label: glyph $i has another bitmap size');
			if (a.isColor != b.isColor) fail('$label: glyph $i colour differs');
		}
	}

	static function main():Void {
		var atlas = FontAtlas.getDefault();
		var style = {size: 14.0, family: "Arimo"};
		// Latin and kerning: exact to a third of a pixel at most.
		var latin = [
			"Label 123: the quick brown fox jumps over the lazy dog",
			"AVATAR To Wa Ty Yo kerning pairs; (parentheses) [brackets]",
			"office fi fl ffi ligature candidates: waffle affix",
			"   leading and  double  spaces ",
			"The quick brown fox jumps over the lazy dog 0123456789",
			"café naïve Ångström über straße",
			"Αβγ Δεζ Привет мир",
			"“quoted” ‘text’ – dashes — and…",
			"line one\nline two\n\nline four"
		];
		for (t in latin) agree(atlas, t, style, 0.05, 0.4);
		// Everything else: one glyph per character placed on its advance, or shaped as a run.
		var others = [
			"Hello 你好 こんにちは 안녕",
			"star ★ check ✓ arrow → end",
			"party 🎉 smile 😀😀 done",
			"mixed שלום and مرحبا text",
			"é combining ä marks"
		];
		for (t in others) agree(atlas, t, style, 0.5, 1.0);
		Sys.println("composed lines agree with whole lines (" + (latin.length + others.length) + " strings)");

		// One advance per UTF-16 unit, adding up to the line's width: what TextLayout gives TextEngine.
		for (t in latin.slice(0, 5).concat(others.slice(0, 3)).concat(["emoji " + String.fromCharCode(0x1F389) + " done", "   leading spaces"])) {
			var advances = atlas.characterAdvances(t, 14.0, style);
			if (advances.length != t.length) fail('"${t.substr(0, 20)}": ${advances.length} advances for ${t.length} characters');
			var sum = 0.0;
			for (a in advances) sum += a;
			var width = atlas.measureText(t, 14.0, style).width;
			if (t.indexOf("\n") < 0 && Math.abs(sum - width) > 0.05) fail('"${t.substr(0, 20)}": advances add up to $sum, width $width');
		}
		Sys.println("character advances add up to the widths");

		// A real clear of the glyph atlas: composed lines must keep agreeing with what is in the atlas afterwards.
		var generation = atlas.generation;
		var every = "";
		for (i in 33...127) every += String.fromCharCode(i);
		var size = 60.0;
		var before = lay(atlas, latin[0], style, false);
		FontAtlas.wordCache(false);
		while (atlas.generation == generation && size < 400) {
			atlas.prepare(every, {size: size, family: "Arimo"});
			size += 7;
		}
		FontAtlas.wordCache(true);
		if (atlas.generation == generation) fail('the atlas was not cleared by size $size');
		var after = lay(atlas, latin[0], style, false);
		var reference = lay(atlas, latin[0], style, true);
		for (i in 0...reference.glyphs.length) {
			var a = after.glyphs[i], b = reference.glyphs[i];
			if (Math.abs((a.u0 - b.u0)) > 0.5 && Math.abs(a.u0 - before.glyphs[i].u0) < 0.01) fail('glyph $i still points where it did before the clear');
			if (Math.abs((a.u1 - a.u0) - (b.u1 - b.u0)) > 0.01) fail('glyph $i has another bitmap size after the clear');
		}
		var moved = false;
		for (i in 0...reference.glyphs.length)
			if (reference.glyphs[i].u0 != before.glyphs[i].u0 || reference.glyphs[i].v0 != before.glyphs[i].v0) moved = true;
		Sys.println('atlas cleared (generation $generation -> ${atlas.generation}); ' + (moved ? "glyph rectangles moved and the cache followed" : "glyph rectangles were reused in place"));
		agree(atlas, latin[1], style, 0.05, 0.4);
		Sys.println("text cache checks passed");
	}
}
