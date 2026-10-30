import puffpuff.text.FontAtlas;

/**
 * Fills the native glyph atlas until it is cleared, then checks that the run composer noticed (it drops what it cached)
 * and still lays text out as the native engine does. Prints "text atlas clear checks passed" or throws.
 */
@:access(puffpuff.text.FontAtlas)
@:access(puffpuff.text.RunComposer)
class TextAtlasClearCheck {
	static function fail(message:String):Void {
		throw 'text atlas clear check failed: $message';
	}

	static function main():Void {
		var atlas = FontAtlas.getDefault();
		var style = {size: 14.0, family: "Arimo"};
		var text = "Label 42: the quick brown fox";

		atlas.composeRuns = true;
		var before = atlas.prepare(text, style);
		var first = before.glyphs[0];
		var drops = atlas.composer.drops;
		var generation = atlas.generation;

		var every = "";
		for (i in 33...127) every += String.fromCharCode(i);
		var size = 60.0;
		while (atlas.generation == generation && size < 400) {
			atlas.prepareNative(every, {size: size, family: "Arimo"});
			size += 7;
		}
		if (atlas.generation == generation) fail('the atlas was not cleared by size $size');
		Sys.println('atlas cleared (generation $generation -> ${atlas.generation}) after sizes up to $size');

		var after = atlas.prepare(text, style);
		if (atlas.composer.drops != drops + 1) fail('composer dropped its cache ${atlas.composer.drops - drops} times, expected once');

		atlas.composeRuns = false;
		var native = atlas.prepare(text, style);
		atlas.composeRuns = true;
		if (after.glyphs.length != native.glyphs.length) fail('${after.glyphs.length} glyphs composed, ${native.glyphs.length} native');
		for (i in 0...native.glyphs.length) {
			var a = after.glyphs[i], n = native.glyphs[i];
			if (Math.abs(a.x - n.x) > 1.0) fail('glyph $i at ${a.x}, native ${n.x}');
			// The bitmap itself must be the one the native engine has now, not a rectangle from before the clear.
			var width = n.u1 - n.u0;
			if (Math.abs((a.u1 - a.u0) - width) > 0.01) fail('glyph $i has a ${a.u1 - a.u0} wide rectangle, native ${width}');
		}
		var moved = false;
		for (i in 0...native.glyphs.length)
			if (native.glyphs[i].u0 != before.glyphs[i].u0 || native.glyphs[i].v0 != before.glyphs[i].v0) moved = true;
		Sys.println(moved ? "glyph rectangles moved with the clear, and the composer follows them" : "glyph rectangles did not move (same slots reused)");
		Sys.println("text atlas clear checks passed");
	}
}
