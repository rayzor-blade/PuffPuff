// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

import lime.app.Event;

class ThreadPool {
	public var currentThreads(default, null):Int = 0;
	public var doWork = new Event<Dynamic->Void>();
	public var maxThreads:Int;
	public var minThreads:Int;
	public var onComplete = new Event<Dynamic->Void>();
	public var onError = new Event<Dynamic->Void>();
	public var onProgress = new Event<Dynamic->Void>();
	public var onRun = new Event<Dynamic->Void>();

	public function new(minThreads:Int = 0, maxThreads:Int = 1) {
		this.minThreads = minThreads;
		this.maxThreads = maxThreads;
	}

	public function queue(state:Dynamic = null):Void {
		onRun.dispatch(state);
		try {
			doWork.dispatch(state);
		} catch (e:Dynamic) {
			sendError(e);
		}
	}

	public function sendComplete(state:Dynamic = null):Void {
		onComplete.dispatch(state);
	}

	public function sendError(state:Dynamic = null):Void {
		onError.dispatch(state);
	}

	public function sendProgress(state:Dynamic = null):Void {
		onProgress.dispatch(state);
	}
}
