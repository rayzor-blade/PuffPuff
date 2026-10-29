// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.app;

/**
 * Lime-compatible Future<T> backed by ash-future (`ash.Future<T>`).
 */
@:allow(lime.app.Promise)
class Future<T> {
	public var error(default, null):Dynamic;
	public var isComplete(default, null):Bool;
	public var isError(default, null):Bool;
	public var value(default, null):T;

	@:noCompletion private var __completeListeners:Array<T->Void>;
	@:noCompletion private var __errorListeners:Array<Dynamic->Void>;
	@:noCompletion private var __progressListeners:Array<Int->Int->Void>;
	@:noCompletion private var __ashFuture:Null<ash.Future<T>>;

	public function new(work:Void->T = null, isAsync:Bool = false) {
		isComplete = false;
		isError = false;

		if (work != null) {
			if (isAsync) {
				var af = new ash.Future<T>();
				__ashFuture = af;
				sys.thread.Thread.create(() -> {
					try {
						var res = work();
						af.resolve(res);
						__complete(res);
					} catch (e:Dynamic) {
						af.reject(e);
						__error(e);
					}
				});
			} else {
				try {
					value = work();
					isComplete = true;
				} catch (e:Dynamic) {
					error = e;
					isError = true;
				}
			}
		}
	}

	/**
	 * Wraps a native `ash.Future<T>` directly into a `lime.app.Future<T>`.
	 */
	public static function fromAshFuture<T>(af:ash.Future<T>):Future<T> {
		var future = new Future<T>();
		future.__ashFuture = af;
		if (af.isReady()) {
			try {
				future.__complete(af.await());
			} catch (e:Dynamic) {
				future.__error(e);
			}
		} else {
			af.then((val:T) -> {
				future.__complete(val);
			}, (err:Dynamic) -> {
				future.__error(err);
			});
		}
		return future;
	}

	public function onComplete(listener:T->Void):Future<T> {
		if (listener != null) {
			if (isComplete) {
				listener(value);
			} else if (!isError) {
				if (__completeListeners == null) __completeListeners = [];
				__completeListeners.push(listener);
			}
		}
		return this;
	}

	public function onError(listener:Dynamic->Void):Future<T> {
		if (listener != null) {
			if (isError) {
				listener(error);
			} else if (!isComplete) {
				if (__errorListeners == null) __errorListeners = [];
				__errorListeners.push(listener);
			}
		}
		return this;
	}

	public function onProgress(listener:Int->Int->Void):Future<T> {
		if (listener != null) {
			if (__progressListeners == null) __progressListeners = [];
			__progressListeners.push(listener);
		}
		return this;
	}

	public function ready(waitTime:Int = -1):Future<T> {
		if (isComplete || isError) {
			return this;
		}
		if (__ashFuture != null) {
			try {
				var res = __ashFuture.await();
				__complete(res);
			} catch (e:Dynamic) {
				__error(e);
			}
		}
		return this;
	}

	public function result(waitTime:Int = -1):Null<T> {
		ready(waitTime);
		return isComplete ? value : null;
	}

	public function then<U>(next:T->Future<U>):Future<U> {
		if (isComplete) {
			return next(value);
		} else if (isError) {
			return Future.withError(error);
		} else {
			var promise = new Promise<U>();
			onError(promise.error);
			onProgress(promise.progress);
			onComplete((val:T) -> {
				var f = next(val);
				f.onError(promise.error);
				f.onComplete(promise.complete);
			});
			return promise.future;
		}
	}

	public static function withError<T>(error:Dynamic):Future<T> {
		var future = new Future<T>();
		future.isError = true;
		future.error = error;
		return future;
	}

	public static function withValue<T>(value:T):Future<T> {
		var future = new Future<T>();
		future.isComplete = true;
		future.value = value;
		return future;
	}

	@:noCompletion private function __complete(val:T):Void {
		if (isComplete || isError) return;
		value = val;
		isComplete = true;
		if (__completeListeners != null) {
			for (l in __completeListeners) l(val);
			__completeListeners = null;
		}
		__errorListeners = null;
		__progressListeners = null;
	}

	@:noCompletion private function __error(err:Dynamic):Void {
		if (isComplete || isError) return;
		error = err;
		isError = true;
		if (__errorListeners != null) {
			for (l in __errorListeners) l(err);
			__errorListeners = null;
		}
		__completeListeners = null;
		__progressListeners = null;
	}

	@:noCompletion private function __progress(progress:Int, total:Int):Void {
		if (isComplete || isError) return;
		if (__progressListeners != null) {
			for (l in __progressListeners) l(progress, total);
		}
	}
}
