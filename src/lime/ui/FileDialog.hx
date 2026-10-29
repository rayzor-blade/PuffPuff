// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.ui;

import haxe.io.Bytes;
import lime.app.Event;
import lime.graphics.ImageFileFormat;

class FileDialog {
	public var onCancel = new Event<Void->Void>();
	public var onOpen = new Event<Bytes->Void>();
	public var onSave = new Event<String->Void>();
	public var onSelect = new Event<String->Void>();
	public var onSelectMultiple = new Event<Array<String>->Void>();

	public function new() {}

	public function browse(type:FileDialogType = null, filter:String = null, defaultPath:String = null, title:String = null):Bool {
		onCancel.dispatch();
		return false;
	}

	public function open(filter:String = null, defaultPath:String = null, title:String = null):Bool {
		onCancel.dispatch();
		return false;
	}

	public function save(data:Bytes, filter:String = null, defaultPath:String = null, title:String = null, type:String = "application/octet-stream"):Bool {
		if (defaultPath != null && data != null) {
			try {
				sys.io.File.saveBytes(defaultPath, data);
				onSave.dispatch(defaultPath);
				return true;
			} catch (_:Dynamic) {}
		}
		onCancel.dispatch();
		return false;
	}
}
