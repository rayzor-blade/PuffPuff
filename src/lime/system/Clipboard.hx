// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

import lime.app.Application;
import lime.app.Event;

/**
	The window system's clipboard text. It needs a window on the screen to reach, so with only headless windows, or none,
	the text is kept in the process instead and never touches the user's clipboard.
**/
@:access(lime.app.Application)
@:access(lime.ui.Window)
class Clipboard {
	public static var onUpdate = new Event<Void->Void>();
	public static var text(get, set):String;

	static var local:String = null;

	static function hasWindowSystem():Bool {
		var app = Application.current;
		if (app == null) return false;
		for (window in app.__windows)
			if (window.__nativeWindow.valid()) return true;
		return false;
	}

	private static function get_text():String {
		if (!hasWindowSystem()) return local;
		return switch (window.Window.clipboardText()) {
			case Some(s): s;
			case None: null;
		};
	}

	private static function set_text(value:String):String {
		if (hasWindowSystem()) {
			window.Window.setClipboardText(value == null ? "" : value);
		} else {
			local = value;
		}
		onUpdate.dispatch();
		return value;
	}
}
