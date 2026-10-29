// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

class ObjectPool<T> {
	public var activeObjects(default, null):Int;
	public var inactiveObjects(default, null):Int;
	public var size(get, set):Null<Int>;

	private var __pool:Array<T>;
	private var __size:Null<Int>;

	public dynamic function create():T {
		return null;
	}

	public dynamic function clean(object:T):Void {}

	public function new(create:Void->T = null, clean:T->Void = null, size:Null<Int> = null) {
		__pool = [];
		activeObjects = 0;
		inactiveObjects = 0;
		if (create != null) this.create = create;
		if (clean != null) this.clean = clean;
		if (size != null) this.size = size;
	}

	public function add(object:T):Void {
		if (object != null && (__size == null || inactiveObjects < __size)) {
			clean(object);
			__pool.push(object);
			inactiveObjects++;
		}
	}

	public function clear():Void {
		__pool.resize(0);
		activeObjects = 0;
		inactiveObjects = 0;
	}

	public function get():T {
		var object:T = null;
		if (inactiveObjects > 0) {
			inactiveObjects--;
			activeObjects++;
			object = __pool.pop();
		} else if (__size == null || activeObjects < __size) {
			object = create();
			if (object != null) activeObjects++;
		}
		return object;
	}

	public function release(object:T):Void {
		if (object == null) return;
		activeObjects--;
		if (__size == null || activeObjects + inactiveObjects < __size) {
			clean(object);
			__pool.push(object);
			inactiveObjects++;
		}
	}

	private inline function get_size():Null<Int> return __size;

	private function set_size(value:Null<Int>):Null<Int> {
		if (value == null) {
			__size = null;
		} else {
			__size = value;
			while (inactiveObjects + activeObjects > value && inactiveObjects > 0) {
				__pool.pop();
				inactiveObjects--;
			}
			while (inactiveObjects + activeObjects < value) {
				var obj = create();
				if (obj == null) break;
				__pool.push(obj);
				inactiveObjects++;
			}
		}
		return value;
	}
}
