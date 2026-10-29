package puffpuff.canvas;

import haxe.ds.IntMap;

/**
 * Uniform-grid broad phase for hit testing drawn shapes by their bounds.
 * Cells are keyed by a packed 32-bit `(i, j)` (16 bits each) in an `IntMap`, so lookups
 * allocate no strings. Items are stored by index; `query*` results come back in insertion
 * (paint) order, so the last match is the topmost.
 */
class SpatialIndex<T> {
	public final cellSize:Float;

	final cells = new IntMap<Array<Int>>();
	final items:Array<T> = [];
	final bounds:Array<Float> = [];

	/** Per-item stamp so an item spanning several cells is reported once per query. **/
	final seen:Array<Int> = [];

	var stamp = 0;

	public function new(cellSize = 64.0) {
		this.cellSize = cellSize;
	}

	public var length(get, never):Int;

	inline function get_length():Int
		return items.length;

	static inline function key(i:Int, j:Int):Int
		return ((i & 0xFFFF) << 16) | (j & 0xFFFF);

	inline function cell(v:Float):Int
		return Math.floor(v / cellSize);

	public function clear():Void {
		cells.clear();
		items.resize(0);
		bounds.resize(0);
		seen.resize(0);
	}

	public function insert(item:T, x0:Float, y0:Float, x1:Float, y1:Float):Int {
		var id = items.length;
		items.push(item);
		bounds.push(x0);
		bounds.push(y0);
		bounds.push(x1);
		bounds.push(y1);
		seen.push(0);
		for (i in cell(x0)...cell(x1) + 1)
			for (j in cell(y0)...cell(y1) + 1) {
				var k = key(i, j);
				var list = cells.get(k);
				if (list == null)
					cells.set(k, list = []);
				list.push(id);
			}
		return id;
	}

	/** Items whose bounds contain `(x, y)`, bottom to top. **/
	public function query(x:Float, y:Float, ?out:Array<T>):Array<T> {
		if (out == null)
			out = [];
		var list = cells.get(key(cell(x), cell(y)));
		if (list == null)
			return out;
		for (id in list) {
			var b = id << 2;
			if (x >= bounds[b] && x <= bounds[b + 2] && y >= bounds[b + 1] && y <= bounds[b + 3])
				out.push(items[id]);
		}
		return out;
	}

	/** Items whose bounds overlap the rect, bottom to top. **/
	public function queryRect(x0:Float, y0:Float, x1:Float, y1:Float, ?out:Array<T>):Array<T> {
		if (out == null)
			out = [];
		stamp++;
		var hits:Array<Int> = [];
		for (i in cell(x0)...cell(x1) + 1)
			for (j in cell(y0)...cell(y1) + 1) {
				var list = cells.get(key(i, j));
				if (list == null)
					continue;
				for (id in list) {
					if (seen[id] == stamp)
						continue;
					seen[id] = stamp;
					var b = id << 2;
					if (x1 >= bounds[b] && x0 <= bounds[b + 2] && y1 >= bounds[b + 1] && y0 <= bounds[b + 3])
						hits.push(id);
				}
			}
		hits.sort((a, b) -> a - b);
		for (id in hits)
			out.push(items[id]);
		return out;
	}
}

