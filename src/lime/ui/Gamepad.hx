package lime.ui;

import lime.app.Event;

/**
 * Lime Gamepad backed by `hlwindow` (`window.Gamepad`).
 */
class Gamepad {
	public static var devices = new Map<Int, Gamepad>();
	public static var onConnect = new Event<Gamepad->Void>();

	public var connected(default, null):Bool;
	public var guid(get, never):String;
	public var id(default, null):Int;
	public var name(get, never):String;

	public var onAxisMove = new Event<GamepadAxis->Float->Void>();
	public var onButtonDown = new Event<GamepadButton->Void>();
	public var onButtonUp = new Event<GamepadButton->Void>();
	public var onDisconnect = new Event<Void->Void>();

	@:noCompletion private var __native:window.Gamepad;

	public function new(id:Int) {
		this.id = id;
		this.connected = true;
		this.__native = window.Gamepad.fromId(id);
	}

	public static function addMappings(mappings:Array<String>):Void {}

	public function rumble(lowFrequency:Float, highFrequency:Float, durationMs:Int):Bool {
		if (!connected || !__native.valid()) return false;
		return __native.rumble(lowFrequency, highFrequency, durationMs / 1000.0);
	}

	@:noCompletion public static function __poll():Void {
		if (!window.Gamepad.available()) return;

		while (true) {
			var ev = window.Gamepad.poll();
			switch (ev) {
				case None:
					break;
				case Connected(devId):
					var pad = devices.get(devId);
					if (pad == null) {
						pad = new Gamepad(devId);
						devices.set(devId, pad);
					} else {
						pad.connected = true;
						pad.__native = window.Gamepad.fromId(devId);
					}
					onConnect.dispatch(pad);
				case Disconnected(devId):
					var pad = devices.get(devId);
					if (pad != null) {
						pad.connected = false;
						devices.remove(devId);
						pad.onDisconnect.dispatch();
					}
				case Button(devId, btn, val, pressed):
					var pad = devices.get(devId);
					if (pad == null) {
						pad = new Gamepad(devId);
						devices.set(devId, pad);
						onConnect.dispatch(pad);
					}
					// LeftTrigger and RightTrigger map to analog axes in Lime/SDL
					if (btn == window.GamepadButton.LeftTrigger) {
						pad.onAxisMove.dispatch(GamepadAxis.TRIGGER_LEFT, val);
					} else if (btn == window.GamepadButton.RightTrigger) {
						pad.onAxisMove.dispatch(GamepadAxis.TRIGGER_RIGHT, val);
					} else {
						var limeBtn = GamepadButton.fromWindowButton(btn);
						if (limeBtn != GamepadButton.UNKNOWN) {
							if (pressed) {
								pad.onButtonDown.dispatch(limeBtn);
							} else {
								pad.onButtonUp.dispatch(limeBtn);
							}
						}
					}
				case Axis(devId, axis, val):
					var pad = devices.get(devId);
					if (pad == null) {
						pad = new Gamepad(devId);
						devices.set(devId, pad);
						onConnect.dispatch(pad);
					}
					var limeAxis = GamepadAxis.fromWindowAxis(axis);
					pad.onAxisMove.dispatch(limeAxis, val);
				case Overflow(_):
			}
		}
	}

	private function get_guid():String {
		return 'hlwindow-gamepad-$id';
	}

	private function get_name():String {
		if (__native.valid()) {
			var n = __native.name();
			if (n != null) return n;
		}
		return 'Gamepad $id';
	}
}
