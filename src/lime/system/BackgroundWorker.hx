// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

import lime.app.Event;

class BackgroundWorker {
	public var canceled(default, null):Bool = false;
	public var completed(default, null):Bool = false;
	public var doWork = new Event<Dynamic->Void>();
	public var onComplete = new Event<Dynamic->Void>();
	public var onError = new Event<Dynamic->Void>();
	public var onProgress = new Event<Dynamic->Void>();

	public function new() {}

	public function cancel():Void {
		canceled = true;
	}

	public function run(message:Dynamic = null):Void {
		canceled = false;
		completed = false;
		try {
			doWork.dispatch(message);
		} catch (e:Dynamic) {
			sendError(e);
		}
	}

	public function sendComplete(message:Dynamic = null):Void {
		if (!canceled && !completed) {
			completed = true;
			onComplete.dispatch(message);
		}
	}

	public function sendError(message:Dynamic = null):Void {
		if (!canceled && !completed) {
			completed = true;
			onError.dispatch(message);
		}
	}

	public function sendProgress(message:Dynamic = null):Void {
		if (!canceled && !completed) {
			onProgress.dispatch(message);
		}
	}
}
