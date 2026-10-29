package lime.ui;

import lime.app.Application;
import lime.app.Config;
import lime.app.Event;
import lime.graphics.Image;
import lime.graphics.RenderContext;
import lime.system.Display;
import lime.system.Display.DisplayMode;
import puffpuff.gpu.WgpuContext;
import window.CursorIcon;
import window.MouseElementState;
import window.MouseScrollDelta;
import window.PhysicalKey;
import window.WindowAttributes;

class Window {
	public var application:Application;
	public var borderless(get, set):Bool;
	public var context(default, null):RenderContext;
	public var cursor(get, set):MouseCursor;
	public var display(get, never):Display;
	public var displayMode(get, set):DisplayMode;
	public var frameRate(get, set):Float;
	public var fullscreen(get, set):Bool;
	public var height(get, set):Int;
	public var hidden(get, never):Bool;
	public var id(default, null):Int;
	public var maximized(get, set):Bool;
	public var minimized(get, set):Bool;
	public var mouseLock(get, set):Bool;
	public var parameters(default, null):Dynamic;
	public var resizable(get, set):Bool;
	public var scale(get, never):Float;
	public var stage:Dynamic;
	public var textInputEnabled(get, set):Bool;
	public var title(get, set):String;
	public var warpMouse(get, set):Bool;
	public var width(get, set):Int;
	public var x(get, set):Int;
	public var y(get, set):Int;

	public var onActivate = new Event<Void->Void>();
	public var onClose = new Event<Void->Void>();
	public var onCreate = new Event<Void->Void>();
	public var onDeactivate = new Event<Void->Void>();
	public var onDropFile = new Event<String->Void>();
	public var onEnter = new Event<Void->Void>();
	public var onExpose = new Event<Void->Void>();
	public var onFocusIn = new Event<Void->Void>();
	public var onFocusOut = new Event<Void->Void>();
	public var onFullscreen = new Event<Void->Void>();
	public var onKeyDown = new Event<KeyCode->KeyModifier->Void>();
	public var onKeyUp = new Event<KeyCode->KeyModifier->Void>();
	public var onLeave = new Event<Void->Void>();
	public var onMinimize = new Event<Void->Void>();
	public var onMouseDown = new Event<Float->Float->MouseButton->Void>();
	public var onMouseMove = new Event<Float->Float->Void>();
	public var onMouseMoveRelative = new Event<Float->Float->Void>();
	public var onMouseUp = new Event<Float->Float->MouseButton->Void>();
	public var onMouseWheel = new Event<Float->Float->MouseWheelMode->Void>();
	public var onMove = new Event<Float->Float->Void>();
	public var onRender = new Event<RenderContext->Void>();
	public var onRenderContextLost = new Event<Void->Void>();
	public var onRenderContextRestored = new Event<RenderContext->Void>();
	public var onResize = new Event<Int->Int->Void>();
	public var onRestore = new Event<Void->Void>();
	public var onTextEdit = new Event<String->Int->Int->Void>();
	public var onTextInput = new Event<String->Void>();

	@:noCompletion public var __nativeWindow:window.Window;
	@:noCompletion public var __wgpuContext:WgpuContext;
	@:noCompletion private var __attributes:WindowConfig;
	@:noCompletion private var __cursor:MouseCursor = DEFAULT;
	@:noCompletion private var __frameRate:Float = 60.0;
	@:noCompletion private var __mouseLock:Bool = false;
	@:noCompletion private var __textInputEnabled:Bool = false;
	@:noCompletion private var __warpMouse:Bool = true;
	@:noCompletion private var __modifiers:KeyModifier = KeyModifier.NONE;
	@:noCompletion private var __lastMouseX:Float = 0.0;
	@:noCompletion private var __lastMouseY:Float = 0.0;
	@:noCompletion private var __closed:Bool = false;

	private static var __nextId:Int = 0;

	public function new(application:Application, attributes:WindowConfig = null) {
		this.application = application;
		this.id = __nextId++;
		this.__attributes = attributes != null ? attributes : {};
		this.parameters = this.__attributes.parameters;

		if (this.__attributes.width == null) this.__attributes.width = 800;
		if (this.__attributes.height == null) this.__attributes.height = 600;
		if (this.__attributes.title == null) this.__attributes.title = "PuffPuff Application";
		if (this.__attributes.resizable == null) this.__attributes.resizable = true;
		if (this.__attributes.vsync == null) this.__attributes.vsync = true;

		var winAttr = new WindowAttributes();
		winAttr.title(this.__attributes.title);
		winAttr.width(this.__attributes.width);
		winAttr.height(this.__attributes.height);
		winAttr.resizable(this.__attributes.resizable);

		if (this.__attributes.x != null) winAttr.x(this.__attributes.x);
		if (this.__attributes.y != null) winAttr.y(this.__attributes.y);
		if (this.__attributes.borderless != null) winAttr.decorations(!this.__attributes.borderless);
		if (this.__attributes.fullscreen != null) winAttr.fullscreen(this.__attributes.fullscreen);
		if (this.__attributes.maximized != null) winAttr.maximized(this.__attributes.maximized);
		if (this.__attributes.hidden != null) winAttr.visible(!this.__attributes.hidden);

		__nativeWindow = window.Window.open(winAttr);
		if (!__nativeWindow.valid()) {
			throw "PuffPuff: Failed to open native hlwindow Window";
		}

		__wgpuContext = new WgpuContext(__nativeWindow, this.__attributes.vsync);
		context = new RenderContext(this, __wgpuContext, this.__attributes);
	}

	@:noCompletion public function __pollEvents():Bool {
		if (__closed || !__nativeWindow.valid()) return false;

		while (true) {
			var ev = __nativeWindow.poll();
			switch (ev) {
				case None:
					break;
				case Closed:
					onClose.dispatch();
					if (!onClose.canceled) {
						close();
						return false;
					}
				case Destroyed:
					__closed = true;
					return false;
				case Resized(w, h):
					var iw = haxe.Int64.toInt(w);
					var ih = haxe.Int64.toInt(h);
					__wgpuContext.configureSurface(iw, ih);
					onResize.dispatch(iw, ih);
				case Moved(nx, ny):
					onMove.dispatch(nx, ny);
				case Focused(focused):
					if (focused) {
						onFocusIn.dispatch();
						onActivate.dispatch();
					} else {
						onFocusOut.dispatch();
						onDeactivate.dispatch();
					}
				case ScaleFactorChanged(sf):
					var pw = Std.int(Math.round(__nativeWindow.width() * sf));
					var ph = Std.int(Math.round(__nativeWindow.height() * sf));
					__wgpuContext.configureSurface(pw, ph);
					onResize.dispatch(pw, ph);
				case RedrawRequested:
					onExpose.dispatch();
				case CursorEntered(_):
					onEnter.dispatch();
				case CursorLeft(_):
					onLeave.dispatch();
				case CursorMoved(mx, my, _):
					var dx = mx - __lastMouseX;
					var dy = my - __lastMouseY;
					__lastMouseX = mx;
					__lastMouseY = my;
					onMouseMove.dispatch(mx, my);
					onMouseMoveRelative.dispatch(dx, dy);
				case MouseInput(state, button, _):
					var limeBtn = MouseButton.fromWindowMouseButton(button);
					if (state == MouseElementState.Pressed) {
						onMouseDown.dispatch(__lastMouseX, __lastMouseY, limeBtn);
					} else {
						onMouseUp.dispatch(__lastMouseX, __lastMouseY, limeBtn);
					}
				case MouseWheel(delta, _, _):
					switch (delta) {
						case LineDelta(lx, ly):
							onMouseWheel.dispatch(lx, ly, MouseWheelMode.LINES);
						case PixelDelta(px, py):
							onMouseWheel.dispatch(px, py, MouseWheelMode.PIXELS);
					}
				case ModifiersChanged(mods):
					switch (mods) {
						case State(shift, ctrl, alt, meta, _, _, _, _, _, _, _, _):
							var m:KeyModifier = KeyModifier.NONE;
							m.shiftKey = shift;
							m.ctrlKey = ctrl;
							m.altKey = alt;
							m.metaKey = meta;
							__modifiers = m;
					}
				case KeyboardInput(_, keyEv, _):
					switch (keyEv) {
						case Input(physKey, _, optText, _, state, _, _):
							var limeKey:KeyCode = switch (physKey) {
								case Code(c): KeyCode.fromWindowKeyCode(c);
								case Unidentified(_): KeyCode.UNKNOWN;
							};
							if (state == MouseElementState.Pressed) {
								onKeyDown.dispatch(limeKey, __modifiers);
								switch (optText) {
									case Some(txt):
										if (txt != null && txt.length > 0) {
											onTextInput.dispatch(txt);
										}
									case None:
								}
							} else {
								onKeyUp.dispatch(limeKey, __modifiers);
							}
					}
				case DroppedFile(filePath):
					switch (filePath) {
						case Utf8(p): onDropFile.dispatch(p);
						default:
					}
				case Touch(devId, phase, tx, ty, force, tid):
					var normX = width > 0 ? tx / width : 0.0;
					var normY = height > 0 ? ty / height : 0.0;
					var press = switch (force) {
						case Normalized(f): f;
						case Calibrated(f, maxF, _): maxF > 0 ? f / maxF : 1.0;
						case None: 1.0;
					};
					var touchObj = new Touch(normX, normY, haxe.Int64.toInt(tid), 0.0, 0.0, press, devId);
					switch (phase) {
						case Started: Touch.onStart.dispatch(touchObj);
						case Moved: Touch.onMove.dispatch(touchObj);
						case Ended: Touch.onEnd.dispatch(touchObj);
						case Cancelled: Touch.onCancel.dispatch(touchObj);
					}
				default:
			}
		}
		return !__closed;
	}

	@:noCompletion public function __renderFrame():Void {
		if (__closed || !__nativeWindow.valid()) return;
		var view = __wgpuContext.beginFrame();
		if (view == null) return;

		if (__attributes.background != null) {
			__wgpuContext.clearColor(__attributes.background, 1.0);
		} else {
			__wgpuContext.clear(0.0, 0.0, 0.0, 1.0);
		}

		onRender.dispatch(context);
		__wgpuContext.endFrame();
	}

	public function alert(message:String, title:String = null):Void {
		Sys.println('[Alert${title != null ? " - " + title : ""}] $message');
	}

	public function close():Void {
		if (__closed) return;
		__closed = true;
		if (__wgpuContext != null) {
			__wgpuContext.destroy();
		}
		if (__nativeWindow.valid()) {
			__nativeWindow.close();
		}
	}

	public function focus():Void {
		if (__nativeWindow.valid()) __nativeWindow.focus();
	}

	public function move(x:Int, y:Int):Void {
		if (__nativeWindow.valid()) __nativeWindow.setPosition(x, y);
	}

	public function resize(width:Int, height:Int):Void {
		if (__nativeWindow.valid()) __nativeWindow.setSize(width, height);
	}

	public function setIcon(image:Image):Void {
		if (__nativeWindow.valid() && image != null && image.data != null) {
			__nativeWindow.setIcon(image.data, image.width, image.height);
		}
	}

	private function get_borderless():Bool return __nativeWindow.valid() ? !__nativeWindow.isDecorated() : false;
	private function set_borderless(v:Bool):Bool {
		if (__nativeWindow.valid()) __nativeWindow.setDecorations(!v);
		return v;
	}

	private function get_cursor():MouseCursor return __cursor;
	private function set_cursor(v:MouseCursor):MouseCursor {
		__cursor = v;
		if (__nativeWindow.valid()) {
			if (v == null) {
				__nativeWindow.setCursorVisible(false);
			} else {
				__nativeWindow.setCursorVisible(true);
				var icon = switch (v) {
					case ARROW | DEFAULT: CursorIcon.Default;
					case CROSSHAIR: CursorIcon.Crosshair;
					case MOVE: CursorIcon.Move;
					case POINTER: CursorIcon.Pointer;
					case RESIZE_NESW: CursorIcon.NeswResize;
					case RESIZE_NS: CursorIcon.NsResize;
					case RESIZE_NWSE: CursorIcon.NwseResize;
					case RESIZE_WE: CursorIcon.EwResize;
					case TEXT: CursorIcon.Text;
					case WAIT: CursorIcon.Wait;
					case WAIT_ARROW: CursorIcon.Progress;
					case CUSTOM: CursorIcon.Default;
				};
				__nativeWindow.setCursorIcon(icon);
			}
		}
		return v;
	}

	private function get_display():Display {
		var disp = new Display();
		if (__nativeWindow.valid()) {
			var mon = __nativeWindow.currentMonitor();
			if (mon.valid()) {
				disp.name = mon.name();
				disp.dpi = 96.0 * mon.scaleFactor();
				disp.currentMode = new DisplayMode(mon.width(), mon.height(), Std.int(mon.refreshRate() / 1000), 0);
			}
		}
		return disp;
	}

	private function get_displayMode():DisplayMode return display.currentMode;
	private function set_displayMode(v:DisplayMode):DisplayMode return v;

	private function get_frameRate():Float return __frameRate;
	private function set_frameRate(v:Float):Float return __frameRate = v;

	private function get_fullscreen():Bool return __nativeWindow.valid() ? __nativeWindow.isFullscreen() : false;
	private function set_fullscreen(v:Bool):Bool {
		if (__nativeWindow.valid()) {
			__nativeWindow.setFullscreen(v);
			if (v) onFullscreen.dispatch();
		}
		return v;
	}

	private function get_height():Int return __nativeWindow.valid() ? __nativeWindow.height() : __attributes.height;
	private function set_height(v:Int):Int {
		resize(width, v);
		return v;
	}

	private function get_hidden():Bool return __nativeWindow.valid() ? !__nativeWindow.isVisible() : false;

	private function get_maximized():Bool return __nativeWindow.valid() ? __nativeWindow.isMaximized() : false;
	private function set_maximized(v:Bool):Bool {
		if (__nativeWindow.valid()) __nativeWindow.setMaximized(v);
		return v;
	}

	private function get_minimized():Bool return __nativeWindow.valid() ? __nativeWindow.isMinimized() : false;
	private function set_minimized(v:Bool):Bool {
		if (__nativeWindow.valid()) {
			__nativeWindow.setMinimized(v);
			if (v) onMinimize.dispatch();
		}
		return v;
	}

	private function get_mouseLock():Bool return __mouseLock;
	private function set_mouseLock(v:Bool):Bool return __mouseLock = v;

	private function get_resizable():Bool return __nativeWindow.valid() ? __nativeWindow.isResizable() : true;
	private function set_resizable(v:Bool):Bool {
		if (__nativeWindow.valid()) __nativeWindow.setResizable(v);
		return v;
	}

	private function get_scale():Float return __nativeWindow.valid() ? __nativeWindow.scaleFactor() : 1.0;

	private function get_textInputEnabled():Bool return __textInputEnabled;
	private function set_textInputEnabled(v:Bool):Bool {
		__textInputEnabled = v;
		if (__nativeWindow.valid()) __nativeWindow.setImeAllowed(v);
		return v;
	}

	private function get_title():String return __nativeWindow.valid() ? __nativeWindow.title() : __attributes.title;
	private function set_title(v:String):String {
		if (__nativeWindow.valid()) __nativeWindow.setTitle(v);
		return v;
	}

	private function get_warpMouse():Bool return __warpMouse;
	private function set_warpMouse(v:Bool):Bool return __warpMouse = v;

	private function get_width():Int return __nativeWindow.valid() ? __nativeWindow.width() : __attributes.width;
	private function set_width(v:Int):Int {
		resize(v, height);
		return v;
	}

	private function get_x():Int return __nativeWindow.valid() ? __nativeWindow.x() : 0;
	private function set_x(v:Int):Int {
		move(v, y);
		return v;
	}

	private function get_y():Int return __nativeWindow.valid() ? __nativeWindow.y() : 0;
	private function set_y(v:Int):Int {
		move(x, v);
		return v;
	}
}
