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

	/** The frame's target and encoder. When the frame was deferred, the first read starts it. **/
	public var currentView(get, never):Null<GpuTextureView>;
	public var currentEncoder(get, never):Null<GpuEncoder>;
	private var view:Null<GpuTextureView>;
	private var encoder:Null<GpuEncoder>;
	/** A surface frame not acquired yet: it is acquired, and `pendingClear` applied, when something first uses it. **/
	private var deferred = false;
	private var pendingClear:Null<Array<Float>>;
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

	private function get_currentView():Null<GpuTextureView> {
		start();
		return view;
	}

	private function get_currentEncoder():Null<GpuEncoder> {
		start();
		return encoder;
	}

	private function start():Void {
		if (deferred) {
			deferred = false;
			beginFrame();
		}
		var clear = pendingClear;
		if (clear != null) {
			pendingClear = null;
			if (view != null && view.valid()) {
				encoder.passReset();
				encoder.passColour(view, clear[0], clear[1], clear[2], clear[3]);
				encoder.passBegin();
				encoder.renderEnd();
			}
		}
	}

	/**
	 * Defers this frame's surface: nothing is acquired, cleared or presented unless something draws. A frame nobody draws
	 * leaves the last presented image on screen, as a retained framebuffer does.
	 */
	public function deferFrame():Void {
		deferred = true;
		pendingClear = null;
	}

	/** Clears with the given color when the frame is first used. A frame nobody draws is left as it was. **/
	public function clearLater(r:Float, g:Float, b:Float, a:Float = 1.0):Void {
		pendingClear = [r, g, b, a];
	}

	public inline function clearColorLater(color:Int, alpha:Float = 1.0):Void {
		clearLater(((color >> 16) & 0xFF) / 255.0, ((color >> 8) & 0xFF) / 255.0, (color & 0xFF) / 255.0, alpha);
	}

	public function beginOffscreen(view:GpuTextureView, width:Int, height:Int):Void {
		this.width = Std.int(Math.max(1, width));
		this.height = Std.int(Math.max(1, height));
		this.view = view;
		this.encoder = device.encoder();
	}

	public function endOffscreen():Void {
		pendingClear = null;
		if (context3D != null) context3D.endRenderPass();
		if (encoder != null && encoder.valid()) {
			encoder.submit(queue);
			encoder.destroy();
			encoder = null;
		}
		view = null;
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
		var acquired = surface.acquire();
		if (!acquired.valid()) {
			return null;
		}
		view = acquired;
		encoder = device.encoder();
		return acquired;
	}

	/**
	 * Clears the active swapchain surface with a solid RGBA color (0.0 - 1.0).
	 */
	public function clear(r:Float, g:Float, b:Float, a:Float = 1.0):Void {
		start();
		if (view == null || !view.valid()) {
			if (beginFrame() == null) return;
		}
		pendingClear = null;
		encoder.passReset();
		encoder.passColour(view, r, g, b, a);
		encoder.passBegin();
		encoder.renderEnd();
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
		deferred = false;
		pendingClear = null;
		if (context3D != null) context3D.endRenderPass();
		if (encoder != null && encoder.valid()) {
			encoder.submit(queue);
			encoder.destroy();
			encoder = null;
		}
		if (view != null && view.valid()) {
			queue.presentSurface(surface);
			view.destroy();
			view = null;
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
		if (encoder != null && encoder.valid()) {
			encoder.destroy();
			encoder = null;
		}
		if (view != null && view.valid()) {
			view.destroy();
			view = null;
		}
		if (surface.valid()) {
			surface.destroy();
		}
	}
}
