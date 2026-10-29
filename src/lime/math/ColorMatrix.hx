// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.math;

import lime.utils.Float32Array;
import lime.utils.UInt8Array;

/**
 * 4x5 color transformation matrix backed by `Float32Array`.
 */
abstract ColorMatrix(Float32Array) from Float32Array to Float32Array {
	public var alphaMultiplier(get, set):Float;
	public var alphaOffset(get, set):Float;
	public var blueMultiplier(get, set):Float;
	public var blueOffset(get, set):Float;
	public var color(get, set):Int;
	public var greenMultiplier(get, set):Float;
	public var greenOffset(get, set):Float;
	public var redMultiplier(get, set):Float;
	public var redOffset(get, set):Float;

	public function new(data:Float32Array = null) {
		if (data != null && data.length == 20) {
			this = data;
		} else {
			this = new Float32Array(20);
			identity();
		}
	}

	public function clone():ColorMatrix {
		var copy = new Float32Array(20);
		copy.buffer.blit(copy.byteOffset, this.buffer, this.byteOffset, 80);
		return new ColorMatrix(copy);
	}

	public function concat(second:ColorMatrix):Void {
		redMultiplier *= second.redMultiplier;
		greenMultiplier *= second.greenMultiplier;
		blueMultiplier *= second.blueMultiplier;
		alphaMultiplier *= second.alphaMultiplier;

		redOffset = redOffset * second.redMultiplier + second.redOffset;
		greenOffset = greenOffset * second.greenMultiplier + second.greenOffset;
		blueOffset = blueOffset * second.blueMultiplier + second.blueOffset;
		alphaOffset = alphaOffset * second.alphaMultiplier + second.alphaOffset;
	}

	public function copyFrom(other:ColorMatrix):Void {
		this.buffer.blit(this.byteOffset, (other : Float32Array).buffer, (other : Float32Array).byteOffset, 80);
	}

	public function identity():Void {
		for (i in 0...20) this[i] = 0.0;
		this[0] = 1.0;
		this[6] = 1.0;
		this[12] = 1.0;
		this[18] = 1.0;
	}

	public function getAlphaTable():UInt8Array {
		var table = new UInt8Array(256);
		var mult = alphaMultiplier;
		var off = alphaOffset * 255;
		for (i in 0...256) {
			var v = Math.floor(i * mult + off);
			table[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
		}
		return table;
	}

	public function getBlueTable():UInt8Array {
		var table = new UInt8Array(256);
		var mult = blueMultiplier;
		var off = blueOffset * 255;
		for (i in 0...256) {
			var v = Math.floor(i * mult + off);
			table[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
		}
		return table;
	}

	public function getGreenTable():UInt8Array {
		var table = new UInt8Array(256);
		var mult = greenMultiplier;
		var off = greenOffset * 255;
		for (i in 0...256) {
			var v = Math.floor(i * mult + off);
			table[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
		}
		return table;
	}

	public function getRedTable():UInt8Array {
		var table = new UInt8Array(256);
		var mult = redMultiplier;
		var off = redOffset * 255;
		for (i in 0...256) {
			var v = Math.floor(i * mult + off);
			table[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
		}
		return table;
	}

	@:arrayAccess
	public inline function get(index:Int):Float return this[index];

	@:arrayAccess
	public inline function set(index:Int, value:Float):Float return this[index] = value;

	private inline function get_alphaMultiplier():Float return this[18];
	private inline function set_alphaMultiplier(v:Float):Float return this[18] = v;
	private inline function get_alphaOffset():Float return this[19] * 255;
	private inline function set_alphaOffset(v:Float):Float { this[19] = v / 255; return v; }
	private inline function get_blueMultiplier():Float return this[12];
	private inline function set_blueMultiplier(v:Float):Float return this[12] = v;
	private inline function get_blueOffset():Float return this[14] * 255;
	private inline function set_blueOffset(v:Float):Float { this[14] = v / 255; return v; }
	private inline function get_greenMultiplier():Float return this[6];
	private inline function set_greenMultiplier(v:Float):Float return this[6] = v;
	private inline function get_greenOffset():Float return this[9] * 255;
	private inline function set_greenOffset(v:Float):Float { this[9] = v / 255; return v; }
	private inline function get_redMultiplier():Float return this[0];
	private inline function set_redMultiplier(v:Float):Float return this[0] = v;
	private inline function get_redOffset():Float return this[4] * 255;
	private inline function set_redOffset(v:Float):Float { this[4] = v / 255; return v; }

	private function get_color():Int {
		return ((Std.int(redOffset) & 0xFF) << 16) | ((Std.int(greenOffset) & 0xFF) << 8) | (Std.int(blueOffset) & 0xFF);
	}

	private function set_color(value:Int):Int {
		redOffset = (value >> 16) & 0xFF;
		greenOffset = (value >> 8) & 0xFF;
		blueOffset = value & 0xFF;
		redMultiplier = greenMultiplier = blueMultiplier = 0;
		return value;
	}
}
