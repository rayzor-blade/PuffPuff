// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.ui;

enum abstract MouseButton(Int) from Int to Int {
	public var LEFT = 0;
	public var MIDDLE = 1;
	public var RIGHT = 2;
	public var EXTRA_1 = 3;
	public var EXTRA_2 = 4;

	public static function fromWindowMouseButton(btn:window.MouseButton):MouseButton {
		return switch (btn) {
			case Left: LEFT;
			case Middle: MIDDLE;
			case Right: RIGHT;
			case Back: EXTRA_1;
			case Forward: EXTRA_2;
			case Other(id): id;
		};
	}
}
