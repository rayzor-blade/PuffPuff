// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.text;

abstract Glyph(Int) from Int to Int {
	public inline function new(i:Int = 0) {
		this = i;
	}
}
