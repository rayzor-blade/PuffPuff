package puffpuff.gpu;

import gpu.GpuAdapter;
import gpu.GpuDevice;
import gpu.GpuEncoder;
import gpu.GpuInstance;
import gpu.GpuQueue;
import gpu.GpuSurface;
import gpu.GpuSurfaceConfiguration;
import gpu.GpuTextureView;
import gpu.Power;
import gpu.PresentMode;
import gpu.TextureFormat;

/**
 * Core WebGPU device, queue, and swapchain surface manager for PuffPuff windows.
 */
class WgpuContext {
	private static var __sharedInstance:Null<GpuInstance> = null;
	private static var __sharedAdapter:Null<GpuAdapter> = null;
	private static var __sharedDevice:Null<GpuDevice> = null;

	public var instance(default, null):GpuInstance;
	public var adapter(default, null):GpuAdapter;
	public var device(default, null):GpuDevice;
	public var queue(default, null):GpuQueue;
	public var surface(default, null):GpuSurface;
	public var surfaceFormat(default, null):TextureFormat;
	public var width(default, null):Int;
	public var height(default, null):Int;
	public var vsync:Bool;

	public var currentView(default, null):Null<GpuTextureView>;
	public var currentEncoder(default, null):Null<GpuEncoder>;
	public var context3D(get, null):WgpuContext3D;

	private function get_context3D():WgpuContext3D {
		if (context3D == null) {
			context3D = new WgpuContext3D(this);
		}
		return context3D;
	}

	public function new(nativeWindow:Null<window.Window>, vsync:Bool = true, offscreenFormat:TextureFormat = Rgba8unorm) {
		this.vsync = vsync;
		ensureSharedDevice();

		this.instance = __sharedInstance;
		this.adapter = __sharedAdapter;
		this.device = __sharedDevice;
		this.queue = device.queue();

		if (nativeWindow != null) {
			this.surface = instance.surface(
				nativeWindow.platform(),
				nativeWindow.raw(0),
				nativeWindow.raw(1),
				nativeWindow.raw(2),
				nativeWindow.raw(3)
			);

			if (!surface.valid()) {
				throw 'PuffPuff: Platform ${nativeWindow.platform()} failed to create a valid GpuSurface';
			}

			this.surfaceFormat = surface.preferredFormat(adapter);
			var scale = nativeWindow.scaleFactor();
			if (scale <= 0) scale = 1.0;

			this.width = Std.int(Math.max(1, Math.round(nativeWindow.width() * scale)));
			this.height = Std.int(Math.max(1, Math.round(nativeWindow.height() * scale)));

			configureSurface(this.width, this.height);
		} else {
			this.surface = 0;
			this.surfaceFormat = offscreenFormat;
			this.width = 1;
			this.height = 1;
		}
	}

	public static function ensureSharedDevice():GpuDevice {
		if (__sharedInstance == null) {
			__sharedInstance = new GpuInstance();
			__sharedAdapter = __sharedInstance.requestAdapter(Power.HighPerformance).await();
			__sharedDevice = __sharedAdapter.requestDevice().await();
		}
		return __sharedDevice;
	}

	/**
	 * Creates a headless/offscreen WgpuContext bound to a target `GpuTextureView` for snapshot/offscreen rendering.
	 */
	public static function createOffscreen(view:GpuTextureView, width:Int, height:Int, format:TextureFormat = Rgba8unorm):WgpuContext {
		var ctx = new WgpuContext(null, false, format);
		ctx.beginOffscreen(view, width, height);
		return ctx;
	}

	public function beginOffscreen(view:GpuTextureView, width:Int, height:Int):Void {
		this.width = Std.int(Math.max(1, width));
		this.height = Std.int(Math.max(1, height));
		this.currentView = view;
		this.currentEncoder = device.encoder();
	}

	public function endOffscreen():Void {
		if (currentEncoder != null && currentEncoder.valid()) {
			currentEncoder.submit(queue);
			currentEncoder.destroy();
			currentEncoder = null;
		}
		currentView = null;
		device.poll();
		if (context3D != null) {
			context3D.flushTempResources();
		}
	}

	public function configureSurface(pixelWidth:Int, pixelHeight:Int):Void {
		if (!surface.valid() || !device.valid()) return;
		this.width = Std.int(Math.max(1, pixelWidth));
		this.height = Std.int(Math.max(1, pixelHeight));

		var config = new GpuSurfaceConfiguration(surfaceFormat, this.width, this.height);
		config.presentMode(vsync ? PresentMode.Fifo : PresentMode.Immediate);
		device.configureSurfaceWith(surface, config);
	}

	public function beginFrame():Null<GpuTextureView> {
		if (!surface.valid() || !device.valid()) return null;
		var view = surface.acquire();
		if (!view.valid()) {
			return null;
		}
		currentView = view;
		currentEncoder = device.encoder();
		return view;
	}

	/**
	 * Clears the active swapchain surface with a solid RGBA color (0.0 - 1.0).
	 */
	public function clear(r:Float, g:Float, b:Float, a:Float = 1.0):Void {
		if (currentView == null || !currentView.valid()) {
			if (beginFrame() == null) return;
		}
		currentEncoder.passReset();
		currentEncoder.passColour(currentView, r, g, b, a);
		currentEncoder.passBegin();
		currentEncoder.renderEnd();
	}

	/**
	 * Clears the active swapchain surface with a 24-bit or 32-bit hex color (0xAARRGGBB or 0xRRGGBB).
	 */
	public inline function clearColor(color:Int, alpha:Float = 1.0):Void {
		var r = ((color >> 16) & 0xFF) / 255.0;
		var g = ((color >> 8) & 0xFF) / 255.0;
		var b = (color & 0xFF) / 255.0;
		clear(r, g, b, alpha);
	}

	public function endFrame():Void {
		if (currentEncoder != null && currentEncoder.valid()) {
			currentEncoder.submit(queue);
			currentEncoder.destroy();
			currentEncoder = null;
		}
		if (currentView != null && currentView.valid()) {
			queue.presentSurface(surface);
			currentView.destroy();
			currentView = null;
		}
		device.poll();
		if (context3D != null) {
			context3D.flushTempResources();
		}
	}

	public function destroy():Void {
		if (context3D != null) {
			context3D.dispose();
			context3D = null;
		}
		if (currentEncoder != null && currentEncoder.valid()) {
			currentEncoder.destroy();
			currentEncoder = null;
		}
		if (currentView != null && currentView.valid()) {
			currentView.destroy();
			currentView = null;
		}
		if (surface.valid()) {
			surface.destroy();
		}
	}
}
