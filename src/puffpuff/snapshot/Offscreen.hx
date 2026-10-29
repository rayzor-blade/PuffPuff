package puffpuff.snapshot;

import gpu.BufferUsage;
import gpu.GpuBufferDescriptor;
import gpu.GpuDevice;
import gpu.GpuExtent3D;
import gpu.GpuTexture;
import gpu.GpuTextureDescriptor;
import gpu.GpuTextureView;
import gpu.GpuTextureViewDescriptor;
import gpu.TextureFormat;
import gpu.TextureUsage;
import haxe.io.Bytes;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.PixelFormat;
import lime.graphics.RenderContext;
import puffpuff.gpu.WgpuContext;

/**
 * Headless/offscreen WebGPU renderer and readback engine for PuffPuff snapshots and visual regression tests.
 */
class Offscreen {
	public final device:GpuDevice;
	public final format:TextureFormat;

	/** Background RGB color cleared before drawing (e.g. `0x1A2B3C`). **/
	public var clear:Int = 0x000000;
	public var clearAlpha:Float = 1.0;
	public var scale:Float = 1.0;

	public function new(device:GpuDevice, format:TextureFormat = Rgba8unorm) {
		this.device = device;
		this.format = format;
	}

	public static function create(format:TextureFormat = Rgba8unorm):Offscreen {
		var dev = WgpuContext.ensureSharedDevice();
		return new Offscreen(dev, format);
	}

	/**
	 * Creates a texture in `format` of `width` x `height` with `RENDER_ATTACHMENT | TEXTURE_BINDING | COPY_SRC`.
	 */
	public function createTexture(width:Int, height:Int):GpuTexture {
		var size = new GpuExtent3D(width);
		size.height(height);
		return device.texture(new GpuTextureDescriptor(
			size,
			format,
			TextureUsage.RENDER_ATTACHMENT | TextureUsage.TEXTURE_BINDING | TextureUsage.COPY_SRC
		));
	}

	/**
	 * Renders `draw(context)` into an offscreen `GpuTextureView` of `width` x `height`.
	 */
	public function render(draw:RenderContext->Void, view:GpuTextureView, width:Int, height:Int):Void {
		var wgpuCtx = WgpuContext.createOffscreen(view, width, height, format);
		var r = ((clear >> 16) & 0xFF) / 255.0;
		var g = ((clear >> 8) & 0xFF) / 255.0;
		var b = (clear & 0xFF) / 255.0;
		wgpuCtx.clear(r, g, b, clearAlpha);

		var renderContext = new RenderContext(null, wgpuCtx, {
			width: width,
			height: height,
			background: clear
		});
		draw(renderContext);
		wgpuCtx.endOffscreen();
	}

	/**
	 * Renders `draw(context)` into a new `GpuTexture` which the caller owns and destroys.
	 */
	public function renderToTexture(draw:RenderContext->Void, width:Int, height:Int):GpuTexture {
		var pixelWidth = Std.int(Math.max(1, Math.round(width * scale)));
		var pixelHeight = Std.int(Math.max(1, Math.round(height * scale)));
		var texture = createTexture(pixelWidth, pixelHeight);
		var view = texture.createView(new GpuTextureViewDescriptor());
		try {
			render(draw, view, pixelWidth, pixelHeight);
		} catch (e:Dynamic) {
			view.destroy();
			texture.destroy();
			throw e;
		}
		view.destroy();
		return texture;
	}

	/**
	 * Renders `draw(context)` offscreen and reads back packed `width * height * 4` RGBA8 bytes.
	 */
	public function renderToRgba8(draw:RenderContext->Void, width:Int, height:Int):Bytes {
		var pixelWidth = Std.int(Math.max(1, Math.round(width * scale)));
		var pixelHeight = Std.int(Math.max(1, Math.round(height * scale)));
		var texture = renderToTexture(draw, width, height);
		var pixels:Bytes;
		try {
			pixels = readRgba8(texture, pixelWidth, pixelHeight);
		} catch (e:Dynamic) {
			texture.destroy();
			throw e;
		}
		texture.destroy();
		return pixels;
	}

	/**
	 * Renders `draw(context)` offscreen and returns a `lime.graphics.Image` holding the RGBA8 pixels.
	 */
	public function renderToImage(draw:RenderContext->Void, width:Int, height:Int):Image {
		var pixelWidth = Std.int(Math.max(1, Math.round(width * scale)));
		var pixelHeight = Std.int(Math.max(1, Math.round(height * scale)));
		var bytes = renderToRgba8(draw, width, height);
		return new Image(new ImageBuffer(bytes, pixelWidth, pixelHeight, 32, PixelFormat.RGBA32), 0, 0, pixelWidth, pixelHeight);
	}

	/**
	 * Reads back `texture` (`COPY_SRC`) into `width * height * 4` tightly packed RGBA8 bytes.
	 */
	public function readRgba8(texture:GpuTexture, width:Int, height:Int):Bytes {
		// WebGPU buffer-to-texture copies require 256-byte row alignment.
		var stride = (width * 4 + 255) & ~255;
		var totalSize:haxe.Int64 = stride * height;
		var readback = device.createBuffer(new GpuBufferDescriptor(
			totalSize,
			BufferUsage.MAP_READ | BufferUsage.COPY_DST
		));
		var encoder = device.encoder();
		encoder.copyTextureToBuffer(texture, readback, width, height, stride);
		encoder.submit(device.queue());
		encoder.destroy();

		device.mapBuffer(readback, 0, totalSize).await();
		var padded = Bytes.alloc(stride * height);
		readback.copyOut(0, padded, padded.length);
		readback.unmap();
		readback.destroy();

		var error = device.takeError();
		if (error != null) {
			throw 'PuffPuff GPU error reading texture back: $error';
		}

		var row = width * 4;
		var out = Bytes.alloc(row * height);
		for (y in 0...height) {
			out.blit(y * row, padded, y * stride, row);
		}
		if (format == Bgra8unorm || format == Bgra8unormSrgb) {
			var i = 0;
			while (i < out.length) {
				var b = out.get(i);
				out.set(i, out.get(i + 2));
				out.set(i + 2, b);
				i += 4;
			}
		}
		return out;
	}
}

