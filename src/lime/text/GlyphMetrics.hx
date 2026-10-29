// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.text;

class GlyphMetrics {
	public var advance:Float;
	public var height:Int;
	public var horizontalBearingX:Float;
	public var horizontalBearingY:Float;
	public var verticalAdvance:Float;
	public var verticalBearingX:Float;
	public var verticalBearingY:Float;
	public var width:Int;

	public function new() {
		advance = 0;
		height = 0;
		horizontalBearingX = 0;
		horizontalBearingY = 0;
		verticalAdvance = 0;
		verticalBearingX = 0;
		verticalBearingY = 0;
		width = 0;
	}
}
