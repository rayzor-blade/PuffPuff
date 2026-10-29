// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.graphics;

enum abstract RenderContextType(String) from String to String {
	public var OPENGL = "opengl";
	public var OPENGLES = "opengles";
	public var WEBGL = "webgl";
	public var CAIRO = "cairo";
	public var CANVAS = "canvas";
	public var DOM = "dom";
	public var FLASH = "flash";
	public var CUSTOM = "custom";
	public var WGPU = "wgpu";
	public var NONE = "none";
}
