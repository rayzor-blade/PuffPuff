// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.app;

import lime.ui.WindowAttributes;

typedef Config = {
	@:optional var build:String;
	@:optional var company:String;
	@:optional var file:String;
	@:optional var fps:Int;
	@:optional var name:String;
	@:optional var orientation:String;
	@:optional var packageName:String;
	@:optional var version:String;
	@:optional var windows:Array<WindowAttributes>;
}

/** Pre-WindowAttributes name, kept so existing code compiles. **/
typedef WindowConfig = WindowAttributes;
