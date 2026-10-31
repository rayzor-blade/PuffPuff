package puffpuff.text;

/**
 * Native bindings to `blinc_abi.hdll` for font registration, text shaping,
 * glyph atlas extraction, and vector outline extraction.
 */
@:hlNative("blinc_abi")
extern class TextNative {
	/**
	 * Registers TTF, OpenType, font collection, or WOFF2 bytes into the shared font database.
	 * Returns the number of font faces added.
	 */
	static function blinc_font_register(bytes:hl.Bytes, len:Int):Int;

	/**
	 * Takes incremental dirty updates from the R8 coverage glyph atlas (`color = 0`)
	 * or RGBA color-glyph atlas (`color = 1`).
	 * Writes `[width, height, revision, dirtyX, dirtyY, dirtyW, dirtyH]` as 7 `i32`s to `info`.
	 * Returns the dirty region's byte size, copying packed rows into `out` if `size <= capacity`.
	 */
	static function blinc_text_atlas_take(color:Int, seen:Int, out:hl.Bytes, capacity:Int, info:hl.Bytes):Int;

	/**
	 * Shapes `text` in `font` (or null for generic/system family) according to `style`
	 * (`[generic, weight, italic, size, letterSpacing, lineHeight]` as 6 `f32`s) and outputs
	 * vector outline commands (`0=moveTo`, `1=lineTo`, `2=quadTo`, `3=cubicTo`, `4=close`) to `out`
	 * and `[widest, ascent, descent, lineHeight]` as 4 `f32`s to `info`.
	 */
	static function blinc_text_outline(text:hl.Bytes, font:hl.Bytes, style:hl.Bytes, out:hl.Bytes, capacity:Int, info:hl.Bytes):Int;

	/**
	 * Shapes `text` and rasterizes glyphs into the shared coverage and color atlases.
	 * Writes 9 `f32`s per glyph to `out`: `[x, y, width, height, u0, v0, u1, v1, isColor]`
	 * and `[widest, ascent, descent, lineHeight]` as 4 `f32`s to `info`.
	 * Returns total `f32`s (`glyphCount * 9`). `flags` is 0, or 1 to round each character's advance to a whole pixel.
	 */
	static function blinc_text_prepare(text:hl.Bytes, font:hl.Bytes, style:hl.Bytes, out:hl.Bytes, capacity:Int, info:hl.Bytes, flags:Int):Int;

	/**
	 * How many times the glyph atlases were cleared to make room. A glyph rectangle taken before a clear is stale after it.
	 */
	static function blinc_text_generation():Int;

	/**
	 * Whether lines are composed from cached words (1, the default) or shaped whole (0). Returns the previous setting.
	 */
	static function blinc_text_word_cache(enabled:Int):Int;

	/**
	 * Writes the advance of every character (Unicode scalar) of `text`, kerning included, as f32s to `out`, and the line's
	 * width as one f32 to `info`. Returns the character count.
	 */
	static function blinc_text_advances(text:hl.Bytes, font:hl.Bytes, style:hl.Bytes, out:hl.Bytes, capacity:Int, info:hl.Bytes, flags:Int):Int;
}

class TextUtf8 {
	public static inline function encode(s:String):hl.Bytes {
		return s == null ? null : @:privateAccess s.toUtf8();
	}
}
