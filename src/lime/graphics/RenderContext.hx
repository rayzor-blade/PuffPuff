package lime.graphics;

import lime.app.Config;
import lime.ui.Window;
import puffpuff.gpu.WgpuContext;

enum abstract RenderContextType(String) from String to String {
	public var OPENGL = "opengl";
	public var OPENGLES = "opengles";
	public var WEBGL = "webgl";
	public var CAIRO = "cairo";
	public var CANVAS = "canvas";
	public var DOM = "dom";
	public var FLASH = "flash";
	public var WGPU = "wgpu";
	public var NONE = "none";
}

class RenderContext {
	public var attributes:WindowConfig;
	public var cairo:Dynamic;
	public var canvas2D:Dynamic;
	public var dom:Dynamic;
	public var flash:Dynamic;
	public var gl:Dynamic;
	public var gles2:Dynamic;
	public var gles3:Dynamic;
	public var type:RenderContextType;
	public var version:String;
	public var webgl:Dynamic;
	public var webgl2:Dynamic;
	public var wgpu:WgpuContext;
	public var window:Window;

	public function new(window:Window, wgpu:WgpuContext, attributes:WindowConfig = null) {
		this.window = window;
		this.wgpu = wgpu;
		this.attributes = attributes;
		this.type = WGPU;
		this.version = "1.0";
	}
}
