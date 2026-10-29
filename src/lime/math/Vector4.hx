package lime.math;

import ash.simd.Float32x4;

class Vector4 {
	public var x:Float;
	public var y:Float;
	public var z:Float;
	public var w:Float;

	public function new(x:Float = 0.0, y:Float = 0.0, z:Float = 0.0, w:Float = 0.0) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}

	public inline function add(a:Vector4, result:Vector4 = null):Vector4 {
		if (result == null) result = new Vector4();
		var va = Float32x4.make(x, y, z, w);
		var vb = Float32x4.make(a.x, a.y, a.z, a.w);
		var vr = va + vb;
		result.setTo(vr.x, vr.y, vr.z, vr.w);
		return result;
	}

	public inline function subtract(a:Vector4, result:Vector4 = null):Vector4 {
		if (result == null) result = new Vector4();
		var va = Float32x4.make(x, y, z, w);
		var vb = Float32x4.make(a.x, a.y, a.z, a.w);
		var vr = va - vb;
		result.setTo(vr.x, vr.y, vr.z, vr.w);
		return result;
	}

	public inline function dotProduct(a:Vector4):Float {
		var va = Float32x4.make(x, y, z, 0.0);
		var vb = Float32x4.make(a.x, a.y, a.z, 0.0);
		return (va * vb).sum();
	}

	public inline function clone():Vector4 {
		return new Vector4(x, y, z, w);
	}

	public inline function copyFrom(sourceVector4:Vector4):Void {
		x = sourceVector4.x;
		y = sourceVector4.y;
		z = sourceVector4.z;
		w = sourceVector4.w;
	}

	public inline function setTo(xa:Float, ya:Float, za:Float, wa:Float = 0.0):Void {
		x = xa;
		y = ya;
		z = za;
		w = wa;
	}

	public var length(get, never):Float;
	private inline function get_length():Float {
		return Math.sqrt(lengthSquared);
	}

	public var lengthSquared(get, never):Float;
	private inline function get_lengthSquared():Float {
		var v = Float32x4.make(x, y, z, 0.0);
		return (v * v).sum();
	}
}
