// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.ui;

enum abstract KeyModifier(Int) from Int to Int {
	public var NONE = 0x0000;
	public var LEFT_SHIFT = 0x0001;
	public var RIGHT_SHIFT = 0x0002;
	public var LEFT_CTRL = 0x0040;
	public var RIGHT_CTRL = 0x0080;
	public var LEFT_ALT = 0x0100;
	public var RIGHT_ALT = 0x0200;
	public var LEFT_META = 0x0400;
	public var RIGHT_META = 0x0800;
	public var NUM_LOCK = 0x1000;
	public var CAPS_LOCK = 0x2000;
	public var MODE = 0x4000;
	public var CTRL = (0x0040 | 0x0080);
	public var SHIFT = (0x0001 | 0x0002);
	public var ALT = (0x0100 | 0x0200);
	public var META = (0x0400 | 0x0800);

	public var altKey(get, set):Bool;
	public var capsLock(get, set):Bool;
	public var ctrlKey(get, set):Bool;
	public var metaKey(get, set):Bool;
	public var numLock(get, set):Bool;
	public var shiftKey(get, set):Bool;

	private inline function get_altKey():Bool return (this & ALT) > 0;
	private inline function set_altKey(v:Bool):Bool { if (v) this |= ALT else this &= ~ALT; return v; }
	private inline function get_capsLock():Bool return (this & CAPS_LOCK) > 0;
	private inline function set_capsLock(v:Bool):Bool { if (v) this |= CAPS_LOCK else this &= ~CAPS_LOCK; return v; }
	private inline function get_ctrlKey():Bool return (this & CTRL) > 0;
	private inline function set_ctrlKey(v:Bool):Bool { if (v) this |= CTRL else this &= ~CTRL; return v; }
	private inline function get_metaKey():Bool return (this & META) > 0;
	private inline function set_metaKey(v:Bool):Bool { if (v) this |= META else this &= ~META; return v; }
	private inline function get_numLock():Bool return (this & NUM_LOCK) > 0;
	private inline function set_numLock(v:Bool):Bool { if (v) this |= NUM_LOCK else this &= ~NUM_LOCK; return v; }
	private inline function get_shiftKey():Bool return (this & SHIFT) > 0;
	private inline function set_shiftKey(v:Bool):Bool { if (v) this |= SHIFT else this &= ~SHIFT; return v; }
}
