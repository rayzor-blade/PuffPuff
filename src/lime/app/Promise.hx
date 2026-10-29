package lime.app;

class Promise<T> {
	public var future(default, null):Future<T>;
	public var isComplete(get, never):Bool;
	public var isError(get, never):Bool;

	public function new() {
		future = new Future<T>();
	}

	public function complete(data:T):Promise<T> {
		future.__complete(data);
		return this;
	}

	public function completeWith(future:Future<T>):Promise<T> {
		future.onComplete(complete);
		future.onError(error);
		future.onProgress(progress);
		return this;
	}

	public function error(msg:Dynamic):Promise<T> {
		future.__error(msg);
		return this;
	}

	public function progress(progress:Int, total:Int):Promise<T> {
		future.__progress(progress, total);
		return this;
	}

	@:noCompletion private inline function get_isComplete():Bool {
		return future.isComplete;
	}

	@:noCompletion private inline function get_isError():Bool {
		return future.isError;
	}
}
