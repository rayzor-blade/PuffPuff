package lime.ui;

enum abstract MouseWheelMode(Int) from Int to Int {
	public var PIXELS = 0;
	public var LINES = 1;
	public var PAGES = 2;
}
