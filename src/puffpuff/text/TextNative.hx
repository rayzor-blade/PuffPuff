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
	 * Returns total `f32`s (`glyphCount * 9`).
	 */
	static function blinc_text_prepare(text:hl.Bytes, font:hl.Bytes, style:hl.Bytes, out:hl.Bytes, capacity:Int, info:hl.Bytes):Int;
}

class TextUtf8 {
	public static inline function encode(s:String):hl.Bytes {
		return s == null ? null : @:privateAccess s.toUtf8();
	}
}
