package puffpuff.gpu.effects;

import gpu.TextureFormat;
import puffpuff.gpu.WgpuContext3D;
import puffpuff.gpu.shaders.BloomShader;
import puffpuff.gpu.shaders.BlurShader;

/**
 * GPU post-processing over `WgpuTexture`s: separable Gaussian blur and dual-Kawase bloom.
 * Intermediate textures are pooled per size and reused across frames. Every call leaves the
 * context rendering to the back buffer.
 */
class PostEffects {
	public static inline var MAX_BLOOM_LEVELS = 6;

	final ctx:WgpuContext3D;
	final pool = new Map<String, Array<WgpuTexture>>();
	final leased:Array<WgpuTexture> = [];

	public function new(ctx:WgpuContext3D) {
		this.ctx = ctx;
	}

	function lease(w:Int, h:Int, format:TextureFormat):WgpuTexture {
		var key = '$w:$h:$format';
		var free = pool.get(key);
		var tex = free != null && free.length > 0 ? free.pop() : ctx.createTexture(w, h, format);
		leased.push(tex);
		return tex;
	}

	/** Returns this frame's intermediates to the pool. Call once the frame is submitted. **/
	public function recycle():Void {
		for (t in leased) {
			var key = '${t.width}:${t.height}:${t.format}';
			var free = pool.get(key);
			if (free == null)
				pool.set(key, free = []);
			free.push(t);
		}
		leased.resize(0);
	}

	inline function blurPass(src:WgpuTexture, dst:WgpuTexture, sx:Float, sy:Float):Void {
		ctx.setRenderToTexture(dst);
		ctx.beginRenderPass(0, 0, 0, 0);
		ctx.drawFullscreen(ctx.shader("blur", BlurShader.WGSL), BlurShader.PARAMS_SIZE, BlurShader.PARAMS_effect, src, sx, sy, 0, 0);
		ctx.endRenderPass();
	}

	/**
	 * Gaussian blur of `src` into `dst` (same size) with standard deviation ≈ `sigma` px.
	 * The 5-fetch kernel (σ₀≈2) is stretched by `spread ≤ 2` and repeated `n` times;
	 * variances add, so σ ≈ 2·spread·√n.
	 */
	public function blur(src:WgpuTexture, dst:WgpuTexture, sigma:Float):Void {
		var spread = Math.min(2.0, Math.max(0.5, sigma / 2));
		var n = Std.int(Math.max(1, Math.ceil(Math.pow(sigma / (2 * spread), 2))));
		var tx = 1.0 / src.width, ty = 1.0 / src.height;
		var a = lease(src.width, src.height, src.format);
		var b = n > 1 ? lease(src.width, src.height, src.format) : dst;
		var from = src;
		for (i in 0...n) {
			var out = i == n - 1 ? dst : b;
			blurPass(from, a, tx * spread, 0);
			blurPass(a, out, 0, ty * spread);
			from = out;
		}
		ctx.setRenderToBackBuffer();
	}

	/**
	 * `dst = src + intensity · bloom(src)`. Pixels brighter than `threshold` (max channel, 0..1)
	 * bleed outward through a half-res pyramid of up to `MAX_BLOOM_LEVELS`.
	 */
	public function bloom(src:WgpuTexture, dst:WgpuTexture, threshold = 0.6, intensity = 1.0):Void {
		var bloomShader = ctx.shader("bloom", BloomShader.WGSL);
		var size = BloomShader.PARAMS_SIZE, off = BloomShader.PARAMS_effect;
		var levels:Array<WgpuTexture> = [];
		var w = src.width, h = src.height;
		while (levels.length < MAX_BLOOM_LEVELS) {
			w = w >> 1;
			h = h >> 1;
			if (w < 8 || h < 8)
				break;
			levels.push(lease(w, h, src.format));
		}
		if (levels.length == 0) {
			copy(src, dst);
			return;
		}
		inline function pass(from:WgpuTexture, to:WgpuTexture, step:Float, value:Float, additive:Bool, clear:Bool) {
			ctx.setRenderToTexture(to);
			if (clear)
				ctx.beginRenderPass(0, 0, 0, 0);
			else
				ctx.beginRenderPass(null);
			ctx.drawFullscreen(bloomShader, size, off, from, 1.0 / from.width, 1.0 / from.height, step, value, additive);
			ctx.endRenderPass();
		}
		pass(src, levels[0], 0, threshold, false, true);
		for (i in 1...levels.length)
			pass(levels[i - 1], levels[i], 1, 0, false, true);
		var i = levels.length - 1;
		while (i > 0) {
			pass(levels[i], levels[i - 1], 2, 0, true, false);
			i--;
		}
		pass(src, dst, 3, 1.0, false, true);
		pass(levels[0], dst, 3, intensity, true, false);
		ctx.setRenderToBackBuffer();
	}

	public function copy(src:WgpuTexture, dst:WgpuTexture):Void {
		ctx.setRenderToTexture(dst);
		ctx.beginRenderPass(0, 0, 0, 0);
		ctx.drawFullscreen(ctx.shader("bloom", BloomShader.WGSL), BloomShader.PARAMS_SIZE, BloomShader.PARAMS_effect, src, 0, 0, 3, 1.0);
		ctx.endRenderPass();
		ctx.setRenderToBackBuffer();
	}

	public function dispose():Void {
		recycle();
		for (list in pool)
			for (t in list)
				t.dispose();
		pool.clear();
	}
}

