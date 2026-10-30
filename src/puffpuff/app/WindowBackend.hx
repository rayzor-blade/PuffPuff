package puffpuff.app;

import lime.ui.Window;

/**
	`openfl.display.Stage` calls this on `window.__backend` to render outside the main loop, after an event. `render` opens
	a frame and `contextFlip` presents it. Both do nothing inside the loop's own frame.
**/
@:access(lime.ui.Window)
class WindowBackend {
	final parent:Window;
	var opened = false;

	public function new(parent:Window) {
		this.parent = parent;
	}

	public function render():Void {
		if (parent.__inFrame || opened || parent.__closed) return;
		opened = parent.__wgpuContext.beginFrame() != null;
	}

	public function contextFlip():Void {
		if (!opened) return;
		opened = false;
		parent.__wgpuContext.endFrame();
	}
}
