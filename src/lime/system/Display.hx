package lime.system;

class DisplayMode {
	public var height:Int;
	public var pixelFormat:Int;
	public var refreshRate:Int;
	public var width:Int;

	public function new(width:Int, height:Int, refreshRate:Int, pixelFormat:Int) {
		this.width = width;
		this.height = height;
		this.refreshRate = refreshRate;
		this.pixelFormat = pixelFormat;
	}
}

class Display {
	public var bounds:Dynamic;
	public var currentMode:DisplayMode;
	public var dpi:Float;
	public var id:Int;
	public var name:String;
	public var supportedModes:Array<DisplayMode>;

	public function new() {
		dpi = 96.0;
		supportedModes = [];
	}
}
