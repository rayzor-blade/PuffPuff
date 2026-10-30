// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.app;

import lime.graphics.RenderContext;
import lime.system.Orientation;
import lime.system.System;
import lime.ui.Gamepad;
import lime.ui.GamepadAxis;
import lime.ui.GamepadButton;
import lime.ui.Joystick;
import lime.ui.JoystickHatPosition;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.MouseButton;
import lime.ui.MouseWheelMode;
import lime.ui.Touch;
import lime.ui.Window;
import lime.ui.WindowAttributes;

/**
	The foundation of most Lime projects: extend it and override the `on` functions.
	Not yet ported from Lime: `menu`, `supportsMenu` and `preloader` (they need `lime.ui.Menu` and `lime.utils.Preloader`).
**/
@:access(lime.ui.Window)
class Application extends Module {
	/** The Application instance that is executing. **/
	public static var current(default, null):Application;

	/** Config this application was created from. **/
	public var config(default, null):Config;

	/** The device's orientation. **/
	public var deviceOrientation(get, never):Orientation;

	/** Meta-data values for the application, such as a version or a package name. **/
	public var meta:Map<String, String>;

	/** A list of currently attached Module instances. **/
	public var modules(default, null):Array<IModule>;

	/** Advanced frame pacing options for the shared main loop. **/
	public var frameOptions(get, set):FrameOptions;

	/** The frame pacing profile of the shared main loop; see `FrameProfile`. **/
	public var frameProfile(get, set):FrameProfile;

	/** Frame rate cap, shared with `Window.frameRate`. **/
	public var frameRate(get, set):Float;

	/** Update events are dispatched each frame, just before rendering. **/
	public var onUpdate = new Event<Int->Void>();

	/** Dispatched when a new window has been created by this application. **/
	public var onCreateWindow = new Event<Window->Void>();

	/** Dispatched when the orientation of the display has changed. **/
	public var onDisplayOrientationChange = new Event<Int->Orientation->Void>();

	/** Dispatched when the orientation of the device has changed. **/
	public var onDeviceOrientationChange = new Event<Orientation->Void>();

	/** Preloader of the current Application. **/
	public var preloader(default, null):Dynamic;

	/** The Window associated with this Application, or the first one if there are several. **/
	public var window(get, null):Window;

	/** Active Window instances. **/
	public var windows(get, null):Array<Window>;

	/** The requested vertical-sync behavior for this application. **/
	public var vsyncMode(get, set):VSyncMode;

	@:noCompletion private var __backend:ApplicationBackend;
	@:noCompletion private var __frameRate:Float;
	@:noCompletion private var __frameConfigured:Bool;
	@:noCompletion private var __frameOptions:FrameOptions;
	@:noCompletion private var __frameProfile:FrameProfile;
	@:noCompletion private var __vsyncMode:VSyncMode;
	@:noCompletion private var __window:Window;
	@:noCompletion private var __windowByID:Map<Int, Window>;
	@:noCompletion private var __windows:Array<Window>;

	/** Creates a new Application instance. **/
	public function new() {
		super();

		if (Application.current == null) {
			Application.current = this;
		}

		meta = new Map();
		modules = new Array();
		__frameRate = 60;
		__frameConfigured = false;
		__frameOptions = {
			timePrecision: TimePrecision.Auto,
			busyWait: BusyWaitMode.Auto,
			uncapMode: UncapMode.Off
		};
		__frameProfile = FrameProfile.Balanced;
		__windowByID = new Map();
		__windows = new Array();
		__vsyncMode = VSyncMode.Off;

		__backend = new ApplicationBackend(this);
		__backend.configureFrameTiming(__frameProfile, __frameRate, __copyFrameOptions(__frameOptions));
		__backend.setVSyncMode(__vsyncMode);

		__registerLimeModule(this);
	}

	/** Adds a new module to the Application. **/
	public function addModule(module:IModule):Void {
		module.__registerLimeModule(this);
		modules.push(module);
	}

	/** Creates `window`s from `config`, as the generated entry point of a Lime project does. **/
	public function create(config:Config):Void {
		this.config = config;

		if (config != null && config.windows != null) {
			for (attributes in config.windows) {
				createWindow(attributes);
			}
		}
	}

	/** Creates a new Window and adds it to the Application. **/
	public function createWindow(attributes:WindowAttributes):Window {
		var window = __createWindow(attributes);
		__addWindow(window);
		return window;
	}

	/** Runs the main loop until every window is closed; returns an exit code, 0 for none. **/
	public function exec():Int {
		Application.current = this;

		if (__windows.length == 0 && config != null) {
			create(config);
		}

		return __backend.exec();
	}

	/** Configures the frame pacing profile, optional overrides and optional vertical-sync mode at runtime. **/
	public function configureFrameTiming(profile:FrameProfile, ?options:FrameOptions, ?vsyncMode:VSyncMode):Void {
		__applyFrameConfiguration(profile, options, vsyncMode, true);
	}

	public function onGamepadAxisMove(gamepad:Gamepad, axis:GamepadAxis, value:Float):Void {}

	public function onGamepadButtonDown(gamepad:Gamepad, button:GamepadButton):Void {}

	public function onGamepadButtonUp(gamepad:Gamepad, button:GamepadButton):Void {}

	public function onGamepadConnect(gamepad:Gamepad):Void {}

	public function onGamepadDisconnect(gamepad:Gamepad):Void {}

	public function onJoystickAxisMove(joystick:Joystick, axis:Int, value:Float):Void {}

	public function onJoystickButtonDown(joystick:Joystick, button:Int):Void {}

	public function onJoystickButtonUp(joystick:Joystick, button:Int):Void {}

	public function onJoystickConnect(joystick:Joystick):Void {}

	public function onJoystickDisconnect(joystick:Joystick):Void {}

	public function onJoystickHatMove(joystick:Joystick, hat:Int, position:JoystickHatPosition):Void {}

	public function onKeyDown(keyCode:KeyCode, modifier:KeyModifier):Void {}

	public function onKeyUp(keyCode:KeyCode, modifier:KeyModifier):Void {}

	public function onModuleExit(code:Int):Void {}

	public function onMouseDown(x:Float, y:Float, button:MouseButton):Void {}

	public function onMouseMove(x:Float, y:Float):Void {}

	public function onMouseMoveRelative(x:Float, y:Float):Void {}

	public function onMouseUp(x:Float, y:Float, button:MouseButton):Void {}

	public function onMouseWheel(deltaX:Float, deltaY:Float, deltaMode:MouseWheelMode):Void {}

	public function onPreloadComplete():Void {}

	public function onPreloadProgress(loaded:Int, total:Int):Void {}

	public function onRenderContextLost():Void {}

	public function onRenderContextRestored(context:RenderContext):Void {}

	public function onTextEdit(text:String, start:Int, length:Int):Void {}

	public function onTextInput(text:String):Void {}

	public function onTouchCancel(touch:Touch):Void {}

	public function onTouchEnd(touch:Touch):Void {}

	public function onTouchMove(touch:Touch):Void {}

	public function onTouchStart(touch:Touch):Void {}

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

	public function onWindowMove(x:Float, y:Float):Void {}

	public function onWindowMinimize():Void {}

	public function onWindowResize(width:Int, height:Int):Void {}

	public function onWindowRestore():Void {}

	/** Removes a module from the Application. **/
	public function removeModule(module:IModule):Void {
		if (module != null) {
			module.__unregisterLimeModule(this);
			modules.remove(module);
		}
	}

	/** Called when a render event is fired on the primary window. **/
	public function render(context:RenderContext):Void {}

	/** Called each frame with the milliseconds since the last update. **/
	public function update(deltaTime:Int):Void {}

	@:noCompletion private function __addWindow(window:Window):Void {
		if (window != null) {
			__windows.push(window);
			__windowByID.set(window.id, window);

			window.onClose.add(__onWindowClose.bind(window), false, -10000);

			if (__window == null) {
				__window = window;

				window.onActivate.add(onWindowActivate);
				window.onRenderContextLost.add(onRenderContextLost);
				window.onRenderContextRestored.add(onRenderContextRestored);
				window.onDeactivate.add(onWindowDeactivate);
				window.onDropFile.add(onWindowDropFile);
				window.onEnter.add(onWindowEnter);
				window.onExpose.add(onWindowExpose);
				window.onFocusIn.add(onWindowFocusIn);
				window.onFocusOut.add(onWindowFocusOut);
				window.onFullscreen.add(onWindowFullscreen);
				window.onKeyDown.add(onKeyDown);
				window.onKeyUp.add(onKeyUp);
				window.onLeave.add(onWindowLeave);
				window.onMinimize.add(onWindowMinimize);
				window.onMouseDown.add(onMouseDown);
				window.onMouseMove.add(onMouseMove);
				window.onMouseMoveRelative.add(onMouseMoveRelative);
				window.onMouseUp.add(onMouseUp);
				window.onMouseWheel.add(onMouseWheel);
				window.onMove.add(onWindowMove);
				window.onRender.add(render);
				window.onResize.add(onWindowResize);
				window.onRestore.add(onWindowRestore);
				window.onTextEdit.add(onTextEdit);
				window.onTextInput.add(onTextInput);

				onWindowCreate();
			}

			window.onCreate.dispatch();
			onCreateWindow.dispatch(window);
		}
	}

	@:noCompletion private function __createWindow(attributes:WindowAttributes):Window {
		var window = new Window(this, attributes);
		if (window.id == -1) return null;
		__seedFrameConfiguration(attributes);
		return window;
	}

	@:noCompletion private override function __registerLimeModule(application:Application):Void {
		application.onUpdate.add(update);
		application.onExit.add(onModuleExit, false, 0);
		application.onExit.add(__onModuleExit, false, -1000);

		for (gamepad in Gamepad.devices) {
			__onGamepadConnect(gamepad);
		}

		Gamepad.onConnect.add(__onGamepadConnect);

		for (joystick in Joystick.devices) {
			__onJoystickConnect(joystick);
		}

		Joystick.onConnect.add(__onJoystickConnect);

		Touch.onCancel.add(onTouchCancel);
		Touch.onStart.add(onTouchStart);
		Touch.onMove.add(onTouchMove);
		Touch.onEnd.add(onTouchEnd);
	}

	@:noCompletion private function __removeWindow(window:Window):Void {
		if (window != null && __windowByID.exists(window.id)) {
			if (__window == window) {
				__window = null;
			}

			__windows.remove(window);
			__windowByID.remove(window.id);
			window.close();

			__checkForAllWindowsClosed();
		}
	}

	@:noCompletion private function __checkForAllWindowsClosed():Void {
		if (__windows.length == 0) {
			System.exit(0);
		}
	}

	@:noCompletion private function __onGamepadConnect(gamepad:Gamepad):Void {
		onGamepadConnect(gamepad);

		gamepad.onAxisMove.add(onGamepadAxisMove.bind(gamepad));
		gamepad.onButtonDown.add(onGamepadButtonDown.bind(gamepad));
		gamepad.onButtonUp.add(onGamepadButtonUp.bind(gamepad));
		gamepad.onDisconnect.add(onGamepadDisconnect.bind(gamepad));
	}

	@:noCompletion private function __onJoystickConnect(joystick:Joystick):Void {
		onJoystickConnect(joystick);

		joystick.onAxisMove.add(onJoystickAxisMove.bind(joystick));
		joystick.onButtonDown.add(onJoystickButtonDown.bind(joystick));
		joystick.onButtonUp.add(onJoystickButtonUp.bind(joystick));
		joystick.onDisconnect.add(onJoystickDisconnect.bind(joystick));
		joystick.onHatMove.add(onJoystickHatMove.bind(joystick));
	}

	@:noCompletion private function __onModuleExit(code:Int):Void {
		if (onExit.canceled) {
			return;
		}

		__unregisterLimeModule(this);
		__backend.exit();
		if (Application.current == this) {
			Application.current = null;
		}
	}

	@:noCompletion private function __onWindowClose(window:Window):Void {
		if (this.window == window) {
			onWindowClose();
		}

		__removeWindow(window);
	}

	@:noCompletion private override function __unregisterLimeModule(application:Application):Void {
		application.onUpdate.remove(update);
		application.onExit.remove(__onModuleExit);
		application.onExit.remove(onModuleExit);

		Gamepad.onConnect.remove(__onGamepadConnect);
		Joystick.onConnect.remove(__onJoystickConnect);
		Touch.onCancel.remove(onTouchCancel);
		Touch.onStart.remove(onTouchStart);
		Touch.onMove.remove(onTouchMove);
		Touch.onEnd.remove(onTouchEnd);
	}

	@:noCompletion private inline function get_frameOptions():FrameOptions {
		return __copyFrameOptions(__frameOptions);
	}

	@:noCompletion private inline function get_frameProfile():FrameProfile {
		return __frameProfile;
	}

	@:noCompletion private inline function get_frameRate():Float {
		return __frameRate;
	}

	@:noCompletion private inline function get_window():Window {
		return __window;
	}

	@:noCompletion private inline function get_windows():Array<Window> {
		return __windows;
	}

	@:noCompletion private inline function get_vsyncMode():VSyncMode {
		return __vsyncMode;
	}

	@:noCompletion private function set_frameOptions(value:FrameOptions):FrameOptions {
		__applyFrameConfiguration(__frameProfile, value, __vsyncMode, true);
		return __copyFrameOptions(__frameOptions);
	}

	@:noCompletion private function set_frameProfile(value:FrameProfile):FrameProfile {
		__applyFrameConfiguration(value, __frameOptions, __vsyncMode, true);
		return __frameProfile;
	}

	@:noCompletion private function set_frameRate(value:Float):Float {
		return __setFrameRateFromWindow(value);
	}

	@:noCompletion private function set_vsyncMode(value:VSyncMode):VSyncMode {
		__applyFrameConfiguration(__frameProfile, __frameOptions, value, true);
		return __vsyncMode;
	}

	@:noCompletion private function get_deviceOrientation():Orientation {
		return __backend.getDeviceOrientation();
	}

	@:noCompletion private function __applyFrameConfiguration(profile:FrameProfile, ?options:FrameOptions, ?vsyncMode:VSyncMode, lock:Bool):Void {
		__frameProfile = (profile != null) ? profile : __frameProfile;
		__frameOptions = __normalizeFrameOptions(options, __frameOptions);
		__vsyncMode = (vsyncMode != null) ? vsyncMode : __vsyncMode;

		if (lock) {
			__frameConfigured = true;
		}

		if (__backend != null) {
			__backend.configureFrameTiming(__frameProfile, __frameRate, __copyFrameOptions(__frameOptions));
			__backend.setVSyncMode(__vsyncMode);
		}
	}

	@:noCompletion private function __copyFrameOptions(value:FrameOptions):FrameOptions {
		if (value == null) {
			return {
				timePrecision: TimePrecision.Auto,
				busyWait: BusyWaitMode.Auto,
				uncapMode: UncapMode.Off
			};
		}

		return {
			timePrecision: value.timePrecision,
			busyWait: value.busyWait,
			uncapMode: value.uncapMode
		};
	}

	@:noCompletion private function __normalizeFrameOptions(value:FrameOptions, fallback:FrameOptions):FrameOptions {
		var base = __copyFrameOptions(fallback);

		if (value == null) {
			return base;
		}

		if (Reflect.hasField(value, "timePrecision")) base.timePrecision = value.timePrecision;
		if (Reflect.hasField(value, "busyWait")) base.busyWait = value.busyWait;
		if (Reflect.hasField(value, "uncapMode")) base.uncapMode = value.uncapMode;

		return base;
	}

	@:noCompletion private function __resolveFrameRate(attributes:WindowAttributes):Float {
		if (__frameConfigured) {
			return __frameRate;
		}

		if (attributes != null && Reflect.hasField(attributes, "frameRate")) {
			return __normalizeFrameRate(attributes.frameRate);
		}

		return __frameRate;
	}

	@:noCompletion private function __resolveFrameOptions(attributes:WindowAttributes):FrameOptions {
		if (__frameConfigured) {
			return __copyFrameOptions(__frameOptions);
		}

		var options = __copyFrameOptions(__frameOptions);

		if (attributes != null && Reflect.hasField(attributes, "frameOptions") && attributes.frameOptions != null) {
			options = __normalizeFrameOptions(attributes.frameOptions, options);
		}

		return options;
	}

	@:noCompletion private function __resolveFrameProfile(attributes:WindowAttributes):FrameProfile {
		if (__frameConfigured) {
			return __frameProfile;
		}

		if (attributes != null && Reflect.hasField(attributes, "frameProfile") && attributes.frameProfile != null) {
			return attributes.frameProfile;
		}

		return __frameProfile;
	}

	@:noCompletion private function __resolveVSyncMode(attributes:WindowAttributes):VSyncMode {
		if (__frameConfigured) {
			return __vsyncMode;
		}

		if (attributes != null && Reflect.hasField(attributes, "context") && attributes.context != null) {
			var context = attributes.context;

			if (Reflect.hasField(context, "vsyncMode") && context.vsyncMode != null) {
				return context.vsyncMode;
			}

			if (Reflect.hasField(context, "vsync") && context.vsync) {
				return VSyncMode.On;
			}
		}

		return __vsyncMode;
	}

	@:allow(lime.ui.Window)
	@:noCompletion private function __seedFrameConfiguration(attributes:WindowAttributes):Void {
		if (__frameConfigured) {
			return;
		}

		__frameRate = __resolveFrameRate(attributes);
		__applyFrameConfiguration(__resolveFrameProfile(attributes), __resolveFrameOptions(attributes), __resolveVSyncMode(attributes), true);
	}

	@:noCompletion private function __setFrameRateFromWindow(value:Float):Float {
		__frameRate = __normalizeFrameRate(value);
		__applyFrameConfiguration(__frameProfile, __frameOptions, __vsyncMode, true);
		return __frameRate;
	}

	@:noCompletion private inline function __getFrameRate():Float {
		return __frameRate;
	}

	@:noCompletion private inline function __normalizeFrameRate(value:Float):Float {
		return (value > 10000) ? 10000 : value;
	}
}

@:noCompletion private typedef ApplicationBackend = puffpuff.app.ApplicationBackend;
