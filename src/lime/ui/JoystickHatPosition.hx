// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.ui;

enum abstract JoystickHatPosition(Int) from Int to Int {
	public var CENTER = 0x00;
	public var UP = 0x01;
	public var RIGHT = 0x02;
	public var DOWN = 0x04;
	public var LEFT = 0x08;
	public var RIGHT_UP = 0x03;
	public var RIGHT_DOWN = 0x06;
	public var LEFT_UP = 0x09;
	public var LEFT_DOWN = 0x0C;

	public var center(get, set):Bool;
	public var down(get, set):Bool;
	public var left(get, set):Bool;
	public var right(get, set):Bool;
	public var up(get, set):Bool;

	public inline function new(value:Int = 0) {
		this = value;
	}

	private inline function get_center():Bool return this == 0;
	private inline function set_center(v:Bool):Bool { if (v) this = 0; return v; }
	private inline function get_down():Bool return (this & DOWN) > 0;
	private inline function set_down(v:Bool):Bool { if (v) this |= DOWN else this &= ~DOWN; return v; }
	private inline function get_left():Bool return (this & LEFT) > 0;
	private inline function set_left(v:Bool):Bool { if (v) this |= LEFT else this &= ~LEFT; return v; }
	private inline function get_right():Bool return (this & RIGHT) > 0;
	private inline function set_right(v:Bool):Bool { if (v) this |= RIGHT else this &= ~RIGHT; return v; }
	private inline function get_up():Bool return (this & UP) > 0;
	private inline function set_up(v:Bool):Bool { if (v) this |= UP else this &= ~UP; return v; }
}
