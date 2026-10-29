// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

import lime.math.Rectangle;

class Display {
	public var bounds:Rectangle;
	public var currentMode:DisplayMode;
	public var dpi:Float;
	public var id:Int;
	public var name:String;
	public var supportedModes:Array<DisplayMode>;

	public function new() {
		dpi = 96.0;
		bounds = new Rectangle(0, 0, 1920, 1080);
		supportedModes = [];
	}
}
