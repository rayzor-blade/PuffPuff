package lime.app;

import haxe.Timer;
import lime.app.Config;
import lime.app.Module;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.MouseButton;
import lime.ui.MouseWheelMode;
import lime.ui.Window;

class Application extends Module {
	public static var current(default, null):Application;

	public var config(default, null):Config;
	public var frameRate(get, set):Float;
	public var meta(default, null):Map<String, String>;
	public var modules(default, null):Array<IModule>;
	public var onUpdate = new Event<Int->Void>();
	public var preloader(default, null):Dynamic;
	public var window(get, never):Window;
	public var windows(default, null):Array<Window>;

	@:noCompletion private var __windowById:Map<Int, Window>;

	public function new() {
		super();

		if (Application.current == null) {
			Application.current = this;
		}

		meta = new Map<String, String>();
		modules = [];
		windows = [];
		__windowById = new Map<Int, Window>();

		onUpdate.add(update);
	}

	public function addModule(module:IModule):Void {
		module._onRegister(this);
		modules.push(module);
	}

	public function create(config:Config):Void {
		this.config = config;

		if (config != null) {
			if (config.windows != null) {
				for (windowConfig in config.windows) {
					createWindow(windowConfig);
				}
			}
		}
	}

	public function createWindow(attributes:WindowConfig = null):Window {
		var win = new Window(this, attributes);
		windows.push(win);
		__windowById.set(win.id, win);

		if (windows.length == 1) {
			win.onActivate.add(onWindowActivate);
			win.onClose.add(onWindowClose);
			win.onCreate.add(onWindowCreate);
			win.onDeactivate.add(onWindowDeactivate);
			win.onDropFile.add(onWindowDropFile);
			win.onEnter.add(onWindowEnter);
			win.onExpose.add(onWindowExpose);
			win.onFocusIn.add(onWindowFocusIn);
			win.onFocusOut.add(onWindowFocusOut);
			win.onFullscreen.add(onWindowFullscreen);
			win.onKeyDown.add(onKeyDown);
			win.onKeyUp.add(onKeyUp);
			win.onLeave.add(onWindowLeave);
			win.onMinimize.add(onWindowMinimize);
			win.onMouseDown.add(onMouseDown);
			win.onMouseMove.add(onMouseMove);
			win.onMouseMoveRelative.add(onMouseMoveRelative);
			win.onMouseUp.add(onMouseUp);
			win.onMouseWheel.add(onMouseWheel);
			win.onMove.add(onWindowMove);
			win.onRender.add(render);
			win.onRenderContextLost.add(onRenderContextLost);
			win.onRenderContextRestored.add(onRenderContextRestored);
			win.onResize.add(onWindowResize);
			win.onRestore.add(onWindowRestore);
			win.onTextEdit.add(onTextEdit);
			win.onTextInput.add(onTextInput);
		}

		win.onCreate.dispatch();
		return win;
	}

	/**
	 * Executes the main application loop backed by hlwindow and hlwgpu.
	 * If `maxFrames > 0`, runs for that many frames and exits cleanly (useful for automated tests).
	 */
	public function exec(maxFrames:Int = -1):Int {
		Application.current = this;

		if (windows.length == 0 && config != null && config.windows != null) {
			create(config);
		}

		var lastTime = Timer.stamp();
		var frameCount = 0;

		while (windows.length > 0) {
			var activeWindows = windows.copy();
			for (win in activeWindows) {
				if (!win.__pollEvents()) {
					windows.remove(win);
					__windowById.remove(win.id);
				}
			}

			if (windows.length == 0) break;

			var now = Timer.stamp();
			var deltaMs = Std.int(Math.max(1, Math.round((now - lastTime) * 1000.0)));
			lastTime = now;

			onUpdate.dispatch(deltaMs);

			for (win in windows) {
				win.__renderFrame();
			}

			frameCount++;
			if (maxFrames > 0 && frameCount >= maxFrames) {
				for (win in windows.copy()) {
					win.close();
				}
				windows.resize(0);
				break;
			}

			var targetFps = frameRate;
			if (targetFps > 0) {
				var elapsed = Timer.stamp() - now;
				var targetFrameTime = 1.0 / targetFps;
				if (elapsed < targetFrameTime) {
					Sys.sleep(targetFrameTime - elapsed);
				}
			}
		}

		onExit.dispatch(0);
		return 0;
	}

	public function onKeyDown(keyCode:KeyCode, modifier:KeyModifier):Void {}
	public function onKeyUp(keyCode:KeyCode, modifier:KeyModifier):Void {}
	public function onMouseDown(x:Float, y:Float, button:MouseButton):Void {}
	public function onMouseMove(x:Float, y:Float):Void {}
	public function onMouseMoveRelative(x:Float, y:Float):Void {}
	public function onMouseUp(x:Float, y:Float, button:MouseButton):Void {}
	public function onMouseWheel(deltaX:Float, deltaY:Float, deltaMode:MouseWheelMode):Void {}
	public function onRenderContextLost():Void {}
	public function onRenderContextRestored(context:RenderContext):Void {}
	public function onTextEdit(text:String, start:Int, length:Int):Void {}
	public function onTextInput(text:String):Void {}
	public function onWindowActivate():Void {}
	public function onWindowClose():Void {}
	public function onWindowCreate():Void {}
	public function onWindowDeactivate():Void {}
	public function onWindowDropFile(file:String):Void {}
	public function onWindowEnter():Void {}
	public function onWindowExpose():Void {}
	public function onWindowFocusIn():Void {}
	public function onWindowFocusOut():Void {}
	public function onWindowFullscreen():Void {}
	public function onWindowLeave():Void {}
	public function onWindowMinimize():Void {}
	public function onWindowMove(x:Float, y:Float):Void {}
	public function onWindowResize(width:Int, height:Int):Void {}
	public function onWindowRestore():Void {}
	public function render(context:RenderContext):Void {}
	public function update(deltaTime:Int):Void {}

	public function removeModule(module:IModule):Void {
		if (module != null) {
			module._onUnregister(this);
			modules.remove(module);
		}
	}

	private function get_frameRate():Float {
		return window != null ? window.frameRate : 60.0;
	}

	private function set_frameRate(value:Float):Float {
		if (window != null) {
			return window.frameRate = value;
		}
		return value;
	}

	private inline function get_window():Window {
		return windows[0];
	}
}
