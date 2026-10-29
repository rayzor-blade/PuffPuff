// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.ui;

enum abstract ScanCode(Int) from Int to Int from KeyCode to KeyCode {
	public var UNKNOWN = 0;
	public var BACKSPACE = 0x2A;
	public var TAB = 0x2B;
	public var RETURN = 0x28;
	public var ESCAPE = 0x29;
	public var SPACE = 0x2C;
	public var A = 0x04;
	public var B = 0x05;
	public var C = 0x06;
	public var D = 0x07;
	public var E = 0x08;
	public var F = 0x09;
	public var G = 0x0A;
	public var H = 0x0B;
	public var I = 0x0C;
	public var J = 0x0D;
	public var K = 0x0E;
	public var L = 0x0F;
	public var M = 0x10;
	public var N = 0x11;
	public var O = 0x12;
	public var P = 0x13;
	public var Q = 0x14;
	public var R = 0x15;
	public var S = 0x16;
	public var T = 0x17;
	public var U = 0x18;
	public var V = 0x19;
	public var W = 0x1A;
	public var X = 0x1B;
	public var Y = 0x1C;
	public var Z = 0x1D;
	public var NUMBER_1 = 0x1E;
	public var NUMBER_2 = 0x1F;
	public var NUMBER_3 = 0x20;
	public var NUMBER_4 = 0x21;
	public var NUMBER_5 = 0x22;
	public var NUMBER_6 = 0x23;
	public var NUMBER_7 = 0x24;
	public var NUMBER_8 = 0x25;
	public var NUMBER_9 = 0x26;
	public var NUMBER_0 = 0x27;
	public var RIGHT = 0x4F;
	public var LEFT = 0x50;
	public var DOWN = 0x51;
	public var UP = 0x52;

	public static inline function fromKeyCode(keyCode:KeyCode):ScanCode {
		return cast keyCode;
	}

	public static inline function toKeyCode(scanCode:ScanCode):KeyCode {
		return cast scanCode;
	}
}
