package puffpuff.text;

import puffpuff.text.TextNative.TextUtf8;

typedef TextStyle = {
	?size:Float,
	?family:String,
	?generic:Int,
	?weight:Int,
	?italic:Bool,
	?letterSpacing:Float,
	?lineHeight:Float,
	?pixel:Bool
}

typedef TextOutline = {
	var commands:Array<Float>;
	var width:Float;
	var ascent:Float;
	var descent:Float;
	var lineHeight:Float;
}

/**
 * Extracts shaped vector glyph outlines (`0=moveTo`, `1=lineTo`, `2=quadTo`, `3=cubicTo`, `4=close`)
 * and line metrics from `blinc_abi`.
 */
class GlyphOutlines {
	static inline var MAX_CACHED = 512;
	static final cache = new Map<String, TextOutline>();
	static final order:Array<String> = [];

	public static function of(text:String, ?style:TextStyle):Null<TextOutline> {
		if (text == null) return null;
		Fonts.ensureBundled();
		var s:TextStyle = style != null ? style : {};
		var size:Float = s.size != null ? s.size : 16.0;
		var weight:Int = s.weight != null ? s.weight : 400;
		var italic = s.italic == true;
		var generic:Int = s.generic != null ? s.generic : 0;
		var spacing:Float = s.letterSpacing != null ? s.letterSpacing : 0.0;
		var leading:Float = s.lineHeight != null ? s.lineHeight : 0.0;

		var key = '${s.family}|$generic|$weight|$italic|$size|$spacing|$leading|$text';
		var existing = cache.get(key);
		if (existing != null) return existing;

		#if hl
		var info = new hl.Bytes(16);
		var fontBytes = s.family == null ? null : TextUtf8.encode(s.family);
		var textBytes = TextUtf8.encode(text);
		var capacity = 4096;
		var out = new hl.Bytes(capacity * 4);
		var set = new hl.Bytes(24);
		set.setF32(0, generic * 1.0);
		set.setF32(4, weight * 1.0);
		set.setF32(8, italic ? 1.0 : 0.0);
		set.setF32(12, size);
		set.setF32(16, spacing);
		set.setF32(20, leading);

		var n = TextNative.blinc_text_outline(textBytes, fontBytes, set, out, capacity, info);
		if (n > capacity) {
			capacity = n;
			out = new hl.Bytes(capacity * 4);
			n = TextNative.blinc_text_outline(textBytes, fontBytes, set, out, capacity, info);
		}
		if (n <= 0 && text.length > 0) return null;

		var outline:TextOutline = {
			commands: [for (i in 0...n) out.getF32(i * 4)],
			width: info.getF32(0),
			ascent: info.getF32(4),
			descent: info.getF32(8),
			lineHeight: info.getF32(12)
		};
		cache.set(key, outline);
		order.push(key);
		if (order.length > MAX_CACHED) {
			cache.remove(order.shift());
		}
		return outline;
		#else
		return null;
		#end
	}
}

