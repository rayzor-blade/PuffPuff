// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.ui;

import lime.app.Event;

class Joystick {
	public static var devices = new Map<Int, Joystick>();
	public static var onConnect = new Event<Joystick->Void>();

	public var connected(default, null):Bool;
	public var guid(get, never):String;
	public var id(default, null):Int;
	public var name(get, never):String;
	public var numAxes(get, never):Int;
	public var numButtons(get, never):Int;
	public var numHats(get, never):Int;
	public var numTrackballs(get, never):Int;
	public var onAxisMove = new Event<Int->Float->Void>();
	public var onButtonDown = new Event<Int->Void>();
	public var onButtonUp = new Event<Int->Void>();
	public var onDisconnect = new Event<Void->Void>();
	public var onHatMove = new Event<Int->JoystickHatPosition->Void>();
	public var onTrackballMove = new Event<Int->Float->Float->Void>();

	public function new(id:Int) {
		this.id = id;
		this.connected = true;
	}

	private inline function get_guid():String return "00000000000000000000000000000000";
	private inline function get_name():String return "Joystick " + id;
	private inline function get_numAxes():Int return 6;
	private inline function get_numButtons():Int return 16;
	private inline function get_numHats():Int return 1;
	private inline function get_numTrackballs():Int return 0;
}
