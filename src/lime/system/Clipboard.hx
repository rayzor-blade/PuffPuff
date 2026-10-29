// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

import lime.app.Event;

class Clipboard {
	public static var onUpdate = new Event<Void->Void>();
	public static var text(get, set):String;

	private static function get_text():String {
		return switch (window.Window.clipboardText()) {
			case Some(s): s;
			case None: null;
		};
	}

	private static function set_text(value:String):String {
		if (value != null) {
			window.Window.setClipboardText(value);
		}
		onUpdate.dispatch();
		return value;
	}
}
