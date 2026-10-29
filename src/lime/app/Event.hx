package lime.app;

class Event<T> {
	public var canceled(default, null):Bool;

	@:noCompletion private var __listeners:Array<T>;
	@:noCompletion private var __priorities:Array<Int>;
	@:noCompletion private var __repeat:Array<Bool>;

	public function new() {
		canceled = false;
		__listeners = [];
		__priorities = [];
		__repeat = [];
	}

	public function add(listener:T, once:Bool = false, priority:Int = 0):Void {
		if (listener == null) return;

		for (i in 0...__priorities.length) {
			if (priority > __priorities[i]) {
				__listeners.insert(i, listener);
				__priorities.insert(i, priority);
				__repeat.insert(i, !once);
				return;
			}
		}

		__listeners.push(listener);
		__priorities.push(priority);
		__repeat.push(!once);
	}

	public function cancel():Void {
		canceled = true;
	}

	public function has(listener:T):Bool {
		if (listener == null) return false;
		for (l in __listeners) {
			if (Reflect.compareMethods(l, listener)) return true;
		}
		return false;
	}

	public function remove(listener:T):Void {
		if (listener == null) return;
		var i = __listeners.length;
		while (--i >= 0) {
			if (Reflect.compareMethods(__listeners[i], listener)) {
				__listeners.splice(i, 1);
				__priorities.splice(i, 1);
				__repeat.splice(i, 1);
			}
		}
	}

	public function removeAll():Void {
		__listeners.resize(0);
		__priorities.resize(0);
		__repeat.resize(0);
	}

	public function dispatch(a:Dynamic = null, b:Dynamic = null, c:Dynamic = null, d:Dynamic = null, e:Dynamic = null, f:Dynamic = null):Void {
		canceled = false;

		var listeners = __listeners.copy();
		var repeat = __repeat.copy();
		var i = 0;

		while (i < listeners.length) {
			var listener = listeners[i];
			if (!repeat[i]) {
				remove(listener);
			}

			var fn:Dynamic = listener;
			if (a == null && b == null && c == null && d == null && e == null && f == null) {
				try {
					fn();
				} catch (_:Dynamic) {
					Reflect.callMethod(null, fn, [a]);
				}
			} else if (b == null && c == null && d == null && e == null && f == null) {
				fn(a);
			} else if (c == null && d == null && e == null && f == null) {
				fn(a, b);
			} else if (d == null && e == null && f == null) {
				fn(a, b, c);
			} else if (e == null && f == null) {
				fn(a, b, c, d);
			} else if (f == null) {
				fn(a, b, c, d, e);
			} else {
				fn(a, b, c, d, e, f);
			}

			if (canceled) {
				break;
			}
			i++;
		}
	}
}
