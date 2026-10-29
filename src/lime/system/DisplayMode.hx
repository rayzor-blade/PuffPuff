// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

import lime.graphics.PixelFormat;

class DisplayMode {
	public var height:Int;
	public var pixelFormat:PixelFormat;
	public var refreshRate:Int;
	public var width:Int;

	public function new(width:Int, height:Int, refreshRate:Int, pixelFormat:PixelFormat) {
		this.width = width;
		this.height = height;
		this.refreshRate = refreshRate;
		this.pixelFormat = pixelFormat;
	}
}
