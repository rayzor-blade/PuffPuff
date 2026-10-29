package lime.ui;

enum abstract GamepadButton(Int) from Int to Int {
	public var A = 0;
	public var B = 1;
	public var X = 2;
	public var Y = 3;
	public var BACK = 4;
	public var GUIDE = 5;
	public var START = 6;
	public var LEFT_STICK = 7;
	public var RIGHT_STICK = 8;
	public var LEFT_SHOULDER = 9;
	public var RIGHT_SHOULDER = 10;
	public var DPAD_UP = 11;
	public var DPAD_DOWN = 12;
	public var DPAD_LEFT = 13;
	public var DPAD_RIGHT = 14;
	public var UNKNOWN = -1;

	public static function fromWindowButton(btn:window.GamepadButton):GamepadButton {
		return switch (btn) {
			case South: A;
			case East: B;
			case West: X;
			case North: Y;
			case Select: BACK;
			case Guide: GUIDE;
			case Start: START;
			case LeftStick: LEFT_STICK;
			case RightStick: RIGHT_STICK;
			case LeftShoulder: LEFT_SHOULDER;
			case RightShoulder: RIGHT_SHOULDER;
			case DPadUp: DPAD_UP;
			case DPadDown: DPAD_DOWN;
			case DPadLeft: DPAD_LEFT;
			case DPadRight: DPAD_RIGHT;
			default: UNKNOWN;
		};
	}

	public static function toString(button:GamepadButton):String {
		return switch (button) {
			case A: "A";
			case B: "B";
			case X: "X";
			case Y: "Y";
			case BACK: "BACK";
			case GUIDE: "GUIDE";
			case START: "START";
			case LEFT_STICK: "LEFT_STICK";
			case RIGHT_STICK: "RIGHT_STICK";
			case LEFT_SHOULDER: "LEFT_SHOULDER";
			case RIGHT_SHOULDER: "RIGHT_SHOULDER";
			case DPAD_UP: "DPAD_UP";
			case DPAD_DOWN: "DPAD_DOWN";
			case DPAD_LEFT: "DPAD_LEFT";
			case DPAD_RIGHT: "DPAD_RIGHT";
			default: "UNKNOWN";
		};
	}
}

