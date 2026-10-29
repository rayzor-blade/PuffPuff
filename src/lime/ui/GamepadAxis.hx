package lime.ui;

enum abstract GamepadAxis(Int) from Int to Int {
	public var LEFT_X = 0;
	public var LEFT_Y = 1;
	public var RIGHT_X = 2;
	public var RIGHT_Y = 3;
	public var TRIGGER_LEFT = 4;
	public var TRIGGER_RIGHT = 5;
	public var UNKNOWN = -1;

	public static function fromWindowAxis(axis:window.GamepadAxis):GamepadAxis {
		return switch (axis) {
			case LeftX: LEFT_X;
			case LeftY: LEFT_Y;
			case RightX: RIGHT_X;
			case RightY: RIGHT_Y;
		};
	}

	public static function toString(axis:GamepadAxis):String {
		return switch (axis) {
			case LEFT_X: "LEFT_X";
			case LEFT_Y: "LEFT_Y";
			case RIGHT_X: "RIGHT_X";
			case RIGHT_Y: "RIGHT_Y";
			case TRIGGER_LEFT: "TRIGGER_LEFT";
			case TRIGGER_RIGHT: "TRIGGER_RIGHT";
			default: "UNKNOWN";
		};
	}
}

