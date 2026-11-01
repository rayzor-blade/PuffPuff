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

	/** Landscape when the display is at least as wide as it is tall, as a desktop monitor is. **/
	public var orientation(get, never):Orientation;

	/** The part of the display apps may use: all of it on a desktop. **/
	public var safeArea(get, never):Rectangle;

	public function new() {
		dpi = 96.0;
		bounds = new Rectangle(0, 0, 1920, 1080);
		supportedModes = [];
	}

	private function get_orientation():Orientation {
		return bounds.width >= bounds.height ? LANDSCAPE : PORTRAIT;
	}

	private function get_safeArea():Rectangle {
		return bounds.clone();
	}
}
