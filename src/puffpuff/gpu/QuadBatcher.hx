package puffpuff.gpu;

import lime.math.Matrix4;
import lime.utils.Float32Array;
import puffpuff.gpu.WgpuContext3D.WgpuTexture;

/**
 * High-speed instanced quad batcher backing OpenFL's `Graphics.drawQuads` / `Tilemap`
 * and HaxeFlixel's `FlxCamera` / `FlxDrawQuadsItem` pipeline.
 */
class QuadBatcher {
	public var context3D(default, null):WgpuContext3D;
	public var capacity(default, null):Int;
	public var count(default, null):Int = 0;
	public var texture:Null<WgpuTexture>;

	/** Shader for this batch's quads (null for the stock one) and its uniform block parameters. **/
	public var custom:Null<CustomQuadShader>;

	public var params:Null<haxe.io.Bytes>;
	public var instanceData(default, null):Float32Array;

	/** Floats per instance: 12, or 20 for `addOffsetQuad`. **/
	final floats:Int;

	public function new(context3D:WgpuContext3D, initialCapacity:Int = 2048, offsets:Bool = false) {
		this.context3D = context3D;
		this.capacity = initialCapacity;
		this.floats = offsets ? 20 : 12;
		this.instanceData = new Float32Array(initialCapacity * floats);
	}

	public inline function begin(texture:WgpuTexture):Void {
		if (this.texture != null && this.texture != texture && count > 0) {
			flush(null);
		}
		this.texture = texture;
		this.count = 0;
	}

	private function ensureCapacity(needed:Int):Void {
		if (needed <= capacity) return;
		var newCap = capacity * 2;
		while (newCap < needed) newCap *= 2;
		var next = new Float32Array(newCap * floats);
		next.buffer.blit(0, instanceData.buffer, 0, count * floats * 4);
		instanceData = next;
		capacity = newCap;
	}

	/**
	 * Adds a single transformed quad to the instanced batch.
	 */
	public inline function addQuad(
		a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float,
		uvX:Float = 0.0, uvY:Float = 0.0, uvW:Float = 1.0, uvH:Float = 1.0,
		alpha:Float = 1.0, tintRgb:Int = 0xFFFFFF
	):Void {
		ensureCapacity(count + 1);
		var base = count * 12;
		var buf = instanceData.buffer;
		var off = instanceData.byteOffset + (base << 2);
		buf.setFloat(off, a);
		buf.setFloat(off + 4, b);
		buf.setFloat(off + 8, c);
		buf.setFloat(off + 12, d);
		buf.setFloat(off + 16, tx);
		buf.setFloat(off + 20, ty);
		buf.setFloat(off + 24, uvX);
		buf.setFloat(off + 28, uvY);
		buf.setFloat(off + 32, uvW);
		buf.setFloat(off + 36, uvH);
		buf.setFloat(off + 40, alpha);
		buf.setFloat(off + 44, tintRgb & 0xFFFFFF);
		count++;
	}

	/**
	 * Adds a quad with a color transform. Multipliers are 0 or more, offsets 0 to 1, and alpha has its own multiplier and
	 * offset.
	 */
	public function addOffsetQuad(
		a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float,
		uvX:Float, uvY:Float, uvW:Float, uvH:Float, alpha:Float,
		multiplyR:Float, multiplyG:Float, multiplyB:Float,
		offsetR:Float, offsetG:Float, offsetB:Float, offsetA:Float
	):Void {
		ensureCapacity(count + 1);
		var buf = instanceData.buffer;
		var off = instanceData.byteOffset + count * 80;
		buf.setFloat(off, a);
		buf.setFloat(off + 4, b);
		buf.setFloat(off + 8, c);
		buf.setFloat(off + 12, d);
		buf.setFloat(off + 16, tx);
		buf.setFloat(off + 20, ty);
		buf.setFloat(off + 24, uvX);
		buf.setFloat(off + 28, uvY);
		buf.setFloat(off + 32, uvW);
		buf.setFloat(off + 36, uvH);
		buf.setFloat(off + 40, alpha);
		buf.setFloat(off + 44, 0);
		buf.setFloat(off + 48, multiplyR);
		buf.setFloat(off + 52, multiplyG);
		buf.setFloat(off + 56, multiplyB);
		buf.setFloat(off + 60, 0);
		buf.setFloat(off + 64, offsetR);
		buf.setFloat(off + 68, offsetG);
		buf.setFloat(off + 72, offsetB);
		buf.setFloat(off + 76, offsetA);
		count++;
	}

	/**
	 * Ingests OpenFL `Graphics.drawQuads(rects, indices, transforms)` directly into the instanced storage buffer.
	 * - `rects`: `[x, y, width, height, ...]` in pixel coordinates of `texture`.
	 * - `indices`: optional quad rect index per instance.
	 * - `transforms`: `[a, b, c, d, tx, ty, ...]` 2D affine matrix per quad.
	 */
	public function addDrawQuads(
		rects:Float32Array,
		indices:Array<Int> = null,
		transforms:Float32Array = null,
		alpha:Float = 1.0,
		tintRgb:Int = 0xFFFFFF
	):Void {
		if (texture == null || rects == null) return;
		var invW = 1.0 / texture.width;
		var invH = 1.0 / texture.height;

		var numQuads = indices != null ? indices.length : (transforms != null ? Std.int(transforms.length / 6) : Std.int(rects.length / 4));
		ensureCapacity(count + numQuads);

		for (i in 0...numQuads) {
			var rectIdx = indices != null ? indices[i] * 4 : i * 4;
			var rx = rects[rectIdx];
			var ry = rects[rectIdx + 1];
			var rw = rects[rectIdx + 2];
			var rh = rects[rectIdx + 3];

			var a = rw;
			var b = 0.0;
			var c = 0.0;
			var d = rh;
			var tx = 0.0;
			var ty = 0.0;

			if (transforms != null) {
				var tIdx = i * 6;
				a = transforms[tIdx] * rw;
				b = transforms[tIdx + 1] * rw;
				c = transforms[tIdx + 2] * rh;
				d = transforms[tIdx + 3] * rh;
				tx = transforms[tIdx + 4];
				ty = transforms[tIdx + 5];
			}

			addQuad(
				a, b, c, d, tx, ty,
				rx * invW, ry * invH, rw * invW, rh * invH,
				alpha, tintRgb
			);
		}
	}

	public function flush(projection:Matrix4):Void {
		if (count <= 0 || texture == null) return;
		context3D.drawQuadsInstanced(texture, projection, instanceData, count, floats == 20, custom, params);
		count = 0;
	}
}
