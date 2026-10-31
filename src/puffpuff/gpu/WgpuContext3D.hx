package puffpuff.gpu;

import gpu.AddressMode;
import gpu.BlendFactor;
import gpu.BlendOperation;
import gpu.BufferUsage;
import gpu.ColorWrite;
import gpu.CompareFunction;
import gpu.CullMode;
import gpu.FilterMode;
import gpu.FrontFace;
import gpu.GpuBindGroup;
import gpu.GpuBindings;
import gpu.GpuBuffer;
import gpu.GpuBufferDescriptor;
import gpu.GpuDevice;
import gpu.GpuExtent3D;
import gpu.GpuOrigin3D;
import gpu.GpuPipeline;
import gpu.GpuRenderPassColorAttachment;
import gpu.GpuColor;
import gpu.GpuRenderPassDepthStencilAttachment;
import gpu.GpuRenderPassDescriptor;
import gpu.LoadOp;
import gpu.StoreOp;
import gpu.GpuSampler;
import gpu.GpuSamplerDescriptor;
import gpu.GpuShader;
import gpu.GpuTexelCopyBufferLayout;
import gpu.GpuTexelCopyTextureInfo;
import gpu.GpuTexture;
import gpu.GpuTextureDescriptor;
import gpu.GpuTextureView;
import gpu.GpuTextureViewDescriptor;
import gpu.IndexFormat;
import gpu.PrimitiveTopology;
import gpu.TextureFormat;
import gpu.TextureUsage;
import gpu.VertexFormat;
import gpu.VertexStepMode;
import haxe.io.Bytes;
import lime.graphics.Image;
import lime.math.Matrix4;
import lime.utils.Float32Array;
import lime.utils.UInt8Array;
import puffpuff.gpu.PipelineCache.VertexAttributeDesc;
import puffpuff.gpu.PipelineCache.VertexBufferLayoutDesc;
import puffpuff.gpu.shaders.AlphaMaskShader;
import puffpuff.gpu.shaders.BitmapFillShader;
import puffpuff.gpu.shaders.DisplayObjectShader;
import puffpuff.gpu.shaders.GraphicsShader;
import puffpuff.gpu.shaders.InstancedQuadShader;
import puffpuff.gpu.shaders.OffsetQuadShader;
import puffpuff.gpu.shaders.TexturedTriangleShader;
import puffpuff.gpu.shaders.VectorPathShader;

/**
 * A `GpuBuffer` that can be uploaded to after a draw in the same frame, as GL allows.
 *
 * `queue.writeBuffer` lands before the whole submission runs, so rewriting a buffer this frame's commands already read
 * would change what those draws see. Such an upload goes to another buffer, seeded from a CPU shadow so a partial
 * upload keeps the rest of the contents. Buffers swapped out in earlier (submitted) frames get reused, so steady state
 * allocates nothing.
 */
class FrameSafeBuffer {
	public var gpuBuffer(default, null):GpuBuffer;

	/** `context.frame` of the last draw reading `gpuBuffer`. **/
	public var drawnFrame:Int = -1;

	final context:WgpuContext3D;
	final usage:Int;
	final size:Int;
	final shadow:Bytes;

	/** End of the furthest byte ever uploaded. The shadow is zero beyond it. **/
	var extent = 0;

	final spare:Array<GpuBuffer> = [];
	final swapped:Array<GpuBuffer> = [];
	var swappedFrame = -1;

	/** `size` is rounded up to 4 bytes, the `writeBuffer` granularity. **/
	public function new(context:WgpuContext3D, size:Int, usage:Int) {
		this.context = context;
		this.size = (Std.int(Math.max(4, size)) + 3) & ~3;
		this.usage = usage | BufferUsage.COPY_DST;
		this.shadow = Bytes.alloc(this.size);
		this.gpuBuffer = create();
	}

	inline function create():GpuBuffer
		return context.wgpu.device.createBuffer(new GpuBufferDescriptor(size, usage));

	/** Writes `len` bytes of `data` from `pos` at byte `offset`, clipped to the buffer. **/
	public function write(offset:Int, data:Bytes, pos:Int, len:Int):Void {
		if (offset < 0 || offset >= size) return;
		len = Std.int(Math.min(len, Math.min(size - offset, data.length - pos)));
		if (len <= 0) return;
		shadow.blit(offset, data, pos, len);
		var end = offset + len;
		if (end > extent) extent = end;
		var queue = context.wgpu.queue;
		if (drawnFrame == context.frame) {
			rename();
			queue.writeBuffer(gpuBuffer, 0, shadow, (extent + 3) & ~3);
			return;
		}
		var from = offset & ~3, to = (end + 3) & ~3;
		if (from == offset && to == end && pos == 0)
			queue.writeBuffer(gpuBuffer, offset, data, len);
		else
			queue.writeBuffer(gpuBuffer, from, shadow.sub(from, to - from), to - from);
	}

	function rename():Void {
		if (swappedFrame != context.frame) {
			for (b in swapped) spare.push(b);
			swapped.resize(0);
			swappedFrame = context.frame;
		}
		swapped.push(gpuBuffer);
		gpuBuffer = spare.length > 0 ? spare.pop() : create();
		drawnFrame = -1;
	}

	public function dispose():Void {
		for (b in swapped) context.retire(b);
		for (b in spare) context.retire(b);
		swapped.resize(0);
		spare.resize(0);
		if (gpuBuffer.valid()) context.retire(gpuBuffer);
	}
}

/**
 * Hardware WebGPU VertexBuffer3D backed by `gpu.GpuBuffer`.
 */
class WgpuVertexBuffer3D {
	public var context(default, null):WgpuContext3D;
	public var numVertices(default, null):Int;
	public var strideFloats(default, null):Int;
	public var strideBytes(default, null):Int;
	public var gpuBuffer(get, never):GpuBuffer;
	public final storage:FrameSafeBuffer;

	inline function get_gpuBuffer():GpuBuffer
		return storage.gpuBuffer;

	public function new(context:WgpuContext3D, numVertices:Int, data32PerVertex:Int) {
		this.context = context;
		this.numVertices = numVertices;
		this.strideFloats = data32PerVertex;
		this.strideBytes = data32PerVertex * 4;
		this.storage = new FrameSafeBuffer(context, Std.int(Math.max(16, numVertices * strideBytes)), BufferUsage.VERTEX);
	}

	public function uploadFromBytes(data:Bytes, startVertex:Int = 0, count:Int = -1):Void {
		if (data == null) return;
		var len = count > 0 ? count * strideBytes : data.length;
		storage.write(startVertex * strideBytes, data, 0, len);
	}

	public function uploadFromFloat32Array(data:Float32Array, startVertex:Int = 0, count:Int = -1):Void {
		if (data == null) return;
		var bytes = data.byteOffset == 0 ? data.buffer : data.buffer.sub(data.byteOffset, data.byteLength);
		uploadFromBytes(bytes, startVertex, count);
	}

	public function dispose():Void {
		storage.dispose();
	}
}

/**
 * Hardware WebGPU IndexBuffer3D backed by `gpu.GpuBuffer`.
 */
class WgpuIndexBuffer3D {
	public var context(default, null):WgpuContext3D;
	public var numIndices(default, null):Int;
	public var gpuBuffer(get, never):GpuBuffer;
	public final storage:FrameSafeBuffer;

	inline function get_gpuBuffer():GpuBuffer
		return storage.gpuBuffer;

	public function new(context:WgpuContext3D, numIndices:Int) {
		this.context = context;
		this.numIndices = numIndices;
		this.storage = new FrameSafeBuffer(context, numIndices * 2, BufferUsage.INDEX);
	}

	/** Odd `startOffset`/`count` work, since the shadow pads each write to 4 bytes. **/
	public function uploadFromBytes(data:Bytes, startOffset:Int = 0, count:Int = -1):Void {
		if (data == null) return;
		var len = count > 0 ? count * 2 : data.length;
		storage.write(startOffset * 2, data, 0, len);
	}

	public function uploadFromArray(indices:Array<Int>, startOffset:Int = 0, count:Int = -1):Void {
		if (indices == null) return;
		var n = count > 0 ? count : indices.length;
		var alignedBytes = (n * 2 + 3) & ~3;
		var bytes = Bytes.alloc(alignedBytes);
		for (i in 0...n) {
			bytes.setUInt16(i * 2, indices[i]);
		}
		uploadFromBytes(bytes, startOffset, n);
	}

	public function dispose():Void {
		storage.dispose();
	}
}

/**
 * Hardware WebGPU 2D Texture + View + Sampler backing OpenFL `RectangleTexture` / `Texture`.
 */
class WgpuTexture {
	public var context(default, null):WgpuContext3D;
	public var width(default, null):Int;
	public var height(default, null):Int;
	public var format(default, null):TextureFormat;
	public var gpuTexture(default, null):GpuTexture;
	public var view(default, null):GpuTextureView;

	public function new(context:WgpuContext3D, width:Int, height:Int, format:TextureFormat = Rgba8unorm) {
		this.context = context;
		this.width = Std.int(Math.max(1, width));
		this.height = Std.int(Math.max(1, height));
		this.format = format;

		var extent = new GpuExtent3D(this.width);
		extent.height(this.height);
		this.gpuTexture = context.wgpu.device.texture(new GpuTextureDescriptor(
			extent,
			format,
			usageOf(format)
		));
		this.view = this.gpuTexture.createView(new GpuTextureViewDescriptor());
	}

	/** Color textures are sampled, drawn into, uploaded to and read back. A depth texture is only drawn into. **/
	static function usageOf(format:TextureFormat):Int {
		return switch (format) {
			case Depth16unorm, Depth24plus, Depth24plusStencil8, Depth32float, Depth32floatStencil8: TextureUsage.RENDER_ATTACHMENT;
			default: TextureUsage.TEXTURE_BINDING | TextureUsage.COPY_DST | TextureUsage.RENDER_ATTACHMENT | TextureUsage.COPY_SRC;
		}
	}

	public function uploadFromBytes(bytes:Bytes, bytesPerRow:Int = 0):Void {
		if (bytes == null) return;
		if (bytesPerRow <= 0) bytesPerRow = width * 4;
		context.wgpu.queue.writeTexture(gpuTexture, bytes, width, height, bytesPerRow);
	}

	public function uploadRegion(x:Int, y:Int, w:Int, h:Int, bytes:Bytes, bytesPerRow:Int = 0):Void {
		if (bytes == null || w <= 0 || h <= 0) return;
		if (bytesPerRow <= 0) bytesPerRow = w * 4;
		var origin = new GpuOrigin3D();
		origin.x(x);
		origin.y(y);
		var destination = new GpuTexelCopyTextureInfo(gpuTexture);
		destination.origin(origin);
		var layout = new GpuTexelCopyBufferLayout();
		layout.bytesPerRow(bytesPerRow);
		layout.rowsPerImage(h);
		var extent = new GpuExtent3D(w);
		extent.height(h);
		context.wgpu.queue.writeTextureWith(destination, bytes, layout, extent);
	}

	public function resize(newWidth:Int, newHeight:Int):Void {
		newWidth = Std.int(Math.max(1, newWidth));
		newHeight = Std.int(Math.max(1, newHeight));
		if (newWidth == width && newHeight == height) return;
		if (view.valid()) view.destroy();
		if (gpuTexture.valid()) gpuTexture.destroy();
		this.width = newWidth;
		this.height = newHeight;
		var extent = new GpuExtent3D(this.width);
		extent.height(this.height);
		this.gpuTexture = context.wgpu.device.texture(new GpuTextureDescriptor(
			extent,
			format,
			usageOf(format)
		));
		this.view = this.gpuTexture.createView(new GpuTextureViewDescriptor());
	}

	public function uploadFromUInt8Array(data:UInt8Array):Void {
		if (data == null) return;
		uploadFromBytes(data.toBytes(), width * 4);
	}

	public function uploadFromImage(image:Image):Void {
		if (image == null || image.data == null) return;
		uploadFromBytes(image.data.toBytes(), image.width * 4);
	}

	public function dispose():Void {
		if (view.valid()) view.destroy();
		if (gpuTexture.valid()) gpuTexture.destroy();
	}
}

/**
 * State tracker and command batcher bridging OpenFL's `Context3D` API to `hlwgpu`.
 */
class WgpuContext3D {
	public var wgpu(default, null):WgpuContext;
	public var pipelineCache(default, null):PipelineCache;

	public var graphicsShader(default, null):GpuShader;
	public var displayObjectShader(default, null):GpuShader;
	public var bitmapFillShader(default, null):GpuShader;
	public var alphaMaskShader(default, null):GpuShader;
	public var instancedQuadShader(default, null):GpuShader;

	public var linearClampSampler(default, null):GpuSampler;
	public var nearestClampSampler(default, null):GpuSampler;
	public var linearRepeatSampler(default, null):GpuSampler;

	/**
	 * Frames submitted so far. `queue.writeBuffer` lands before the whole submission runs, so a buffer drawn in this frame
	 * can't be rewritten in place until `frame` moves on.
	 */
	public var frame(default, null):Int = 0;

	// Tracked Context3D state
	public var blendEnabled:Bool = true;

	static inline var DEPTH_FORMAT = TextureFormat.Depth24plus;

	/** While enabled, draws are clipped to the scissor rectangle (target pixels from the top left). **/
	public var scissorEnabled(default, null) = false;

	var scissorX = 0;
	var scissorY = 0;
	var scissorWidth = 0;
	var scissorHeight = 0;

	/** Whether the next `drawQuadsInstanced` texture is premultiplied. Set the blend factors to match. **/
	public var quadsPremultiplied:Bool = false;

	/** Whether the next `drawTexturedTriangles` texture is premultiplied. Set the blend factors to match. **/
	public var trianglesPremultiplied:Bool = false;

	var triangleBuffer:Null<GpuBuffer>;
	var triangleCapacity = 0;
	var triangleUsed = 0;
	var triangleFrame = -1;

	/** Whether the next `drawVectorMesh` writes premultiplied color. Set the blend factors to match. **/
	public var vectorsPremultiplied:Bool = false;
	public var srcRgb:BlendFactor = BlendFactor.SrcAlpha;
	public var dstRgb:BlendFactor = BlendFactor.OneMinusSrcAlpha;
	public var opRgb:BlendOperation = BlendOperation.Add;
	public var srcAlpha:BlendFactor = BlendFactor.One;
	public var dstAlpha:BlendFactor = BlendFactor.OneMinusSrcAlpha;
	public var opAlpha:BlendOperation = BlendOperation.Add;
	public var colorWriteMask:Int = ColorWrite.ALL;
	public var depthWrite:Bool = false;
	public var depthCompare:CompareFunction = CompareFunction.Always;
	public var cullMode:CullMode = CullMode.None;
	public var frontFace:FrontFace = FrontFace.Ccw;
	public var smoothing:Bool = true;
	public var repeat:Bool = false;

	/** Program for `drawProgram`. **/
	public var program:Null<HxslProgram>;

	/** Whether passes have a depth attachment. Draws and pipelines then all use it, so set it between passes. **/
	public var depthEnabled(default, set):Bool = false;

	private function set_depthEnabled(value:Bool):Bool {
		if (value != depthEnabled) endRenderPass();
		return depthEnabled = value;
	}

	private var depthTexture:Null<WgpuTexture>;
	private var retiredTextures:Array<WgpuTexture> = [];
	private var textureSlots:Array<Null<WgpuTexture>> = [];
	private var slotRepeat:Array<Null<Bool>> = [];
	private var slotSmooth:Array<Null<Bool>> = [];
	private var currentShader:GpuShader;
	private var activeTexture:Null<WgpuTexture>;
	private var vertexBuffers:Map<Int, {buffer:WgpuVertexBuffer3D, offset:Int, format:VertexFormat}>;
	private var passActive:Bool = false;
	private var tempResources:Array<{buffers:Array<GpuBuffer>, bindGroups:Array<GpuBindGroup>}>;

	/** Null = the frame view. Switch only between passes. **/
	private var renderTarget:Null<WgpuTexture> = null;

	private var lazyShaders:Map<String, GpuShader> = new Map();

	public function new(wgpu:WgpuContext) {
		this.wgpu = wgpu;
		var dev = wgpu.device;
		this.pipelineCache = new PipelineCache(dev);
		this.vertexBuffers = new Map();
		this.tempResources = [];

		// Compile stock HXSL shaders to WGSL modules
		this.graphicsShader = dev.createShader(GraphicsShader.WGSL);
		this.displayObjectShader = dev.createShader(DisplayObjectShader.WGSL);
		this.bitmapFillShader = dev.createShader(BitmapFillShader.WGSL);
		this.alphaMaskShader = dev.createShader(AlphaMaskShader.WGSL);
		this.instancedQuadShader = dev.createShader(InstancedQuadShader.WGSL);
		this.currentShader = this.displayObjectShader;

		// Create cached samplers
		var linClamp = new GpuSamplerDescriptor();
		linClamp.magFilter(FilterMode.Linear);
		linClamp.minFilter(FilterMode.Linear);
		linClamp.addressModeU(AddressMode.ClampToEdge);
		linClamp.addressModeV(AddressMode.ClampToEdge);
		this.linearClampSampler = dev.sampler(linClamp);

		var nearClamp = new GpuSamplerDescriptor();
		nearClamp.magFilter(FilterMode.Nearest);
		nearClamp.minFilter(FilterMode.Nearest);
		nearClamp.addressModeU(AddressMode.ClampToEdge);
		nearClamp.addressModeV(AddressMode.ClampToEdge);
		this.nearestClampSampler = dev.sampler(nearClamp);

		var linRepeat = new GpuSamplerDescriptor();
		linRepeat.magFilter(FilterMode.Linear);
		linRepeat.minFilter(FilterMode.Linear);
		linRepeat.addressModeU(AddressMode.Repeat);
		linRepeat.addressModeV(AddressMode.Repeat);
		this.linearRepeatSampler = dev.sampler(linRepeat);
	}

	public function createVertexBuffer(numVertices:Int, data32PerVertex:Int):WgpuVertexBuffer3D {
		return new WgpuVertexBuffer3D(this, numVertices, data32PerVertex);
	}

	public function createIndexBuffer(numIndices:Int):WgpuIndexBuffer3D {
		return new WgpuIndexBuffer3D(this, numIndices);
	}

	public function createTexture(width:Int, height:Int, format:TextureFormat = Rgba8unorm):WgpuTexture {
		return new WgpuTexture(this, width, height, format);
	}

	public function setBlendFactors(sourceFactor:BlendFactor, destinationFactor:BlendFactor):Void {
		blendEnabled = true;
		srcRgb = sourceFactor;
		dstRgb = destinationFactor;
		srcAlpha = sourceFactor;
		dstAlpha = destinationFactor;
	}

	public function setDepthTest(depthMask:Bool, passCompareMode:CompareFunction):Void {
		depthWrite = depthMask;
		depthCompare = passCompareMode;
	}

	public function setCulling(mode:CullMode):Void {
		cullMode = mode;
	}

	/** Sampling for the texture in `slot` with `drawProgram`, over `smoothing` and `repeat`. **/
	public function setSamplerAt(slot:Int, repeat:Bool, smooth:Bool):Void {
		slotRepeat[slot] = repeat;
		slotSmooth[slot] = smooth;
	}

	public function setTextureAt(samplerSlot:Int, texture:Null<WgpuTexture>):Void {
		textureSlots[samplerSlot] = texture;
		if (samplerSlot == 0) {
			activeTexture = texture;
		}
	}

	public function setVertexBufferAt(index:Int, buffer:Null<WgpuVertexBuffer3D>, bufferOffset:Int = 0, format:VertexFormat = Float32x2):Void {
		if (buffer == null) {
			vertexBuffers.remove(index);
		} else {
			vertexBuffers.set(index, {
				buffer: buffer,
				offset: bufferOffset * 4,
				format: format
			});
		}
	}

	/** Redirects subsequent passes into `texture` (needs `RENDER_ATTACHMENT`). Ends any open pass. **/
	public function setRenderToTexture(texture:WgpuTexture):Void {
		endRenderPass();
		renderTarget = texture;
	}

	public function setRenderToBackBuffer():Void {
		endRenderPass();
		renderTarget = null;
	}

	public inline function targetFormat():TextureFormat {
		return renderTarget != null ? renderTarget.format : wgpu.surfaceFormat;
	}

	public inline function targetWidth():Int {
		return renderTarget != null ? renderTarget.width : wgpu.width;
	}

	public inline function targetHeight():Int {
		return renderTarget != null ? renderTarget.height : wgpu.height;
	}

	/** WGSL modules compiled on first use, so apps that never touch vectors/effects pay nothing. **/
	public function shader(key:String, wgsl:String):GpuShader {
		var s = lazyShaders.get(key);
		if (s == null) {
			s = wgpu.device.createShader(wgsl);
			lazyShaders.set(key, s);
		}
		return s;
	}

	/**
	 * Starts a pass on the target. Clears color to the given value if `clearR` is set, else keeps it. With depth enabled,
	 * clears depth to `clearDepth` if that is set, else keeps it.
	 */
	public function beginRenderPass(clearR:Null<Float> = null, clearG:Float = 0.0, clearB:Float = 0.0, clearA:Float = 1.0, clearDepth:Null<Float> = null):Void {
		if (passActive) return;
		var enc = wgpu.currentEncoder;
		var view = renderTarget != null ? renderTarget.view : wgpu.currentView;
		if (enc == null || view == null) return;

		if (clearR != null && !depthEnabled) {
			enc.passReset();
			enc.passColour(view, clearR, clearG, clearB, clearA);
			enc.passBegin();
		} else {
			// `passColor` always clears and has no depth, so other passes spell out their attachments.
			var attachment = new GpuRenderPassColorAttachment(clearR != null ? LoadOp.Clear : LoadOp.Load, StoreOp.Store);
			attachment.viewTextureView(view);
			if (clearR != null) attachment.clearValue(new GpuColor(clearR, clearG, clearB, clearA));
			var desc = new GpuRenderPassDescriptor();
			desc.addColorAttachments(attachment);
			if (depthEnabled) {
				var depth = new GpuRenderPassDepthStencilAttachment();
				depth.viewTextureView(depthFor(targetWidth(), targetHeight()).view);
				depth.depthLoadOp(clearDepth != null ? LoadOp.Clear : LoadOp.Load);
				depth.depthStoreOp(StoreOp.Store);
				depth.depthClearValue(clearDepth != null ? clearDepth : 1.0);
				desc.depthStencilAttachment(depth);
			}
			enc.beginRenderPass(desc);
		}
		enc.renderSetViewport(0, 0, targetWidth(), targetHeight(), 0.0, 1.0);
		passActive = true;
		applyScissor();
	}

	/** Depth texture for a target of this size. One is kept, so a target of another size starts with cleared depth. **/
	function depthFor(width:Int, height:Int):WgpuTexture {
		if (depthTexture != null && (depthTexture.width != width || depthTexture.height != height)) {
			retiredTextures.push(depthTexture);
			depthTexture = null;
		}
		if (depthTexture == null) depthTexture = new WgpuTexture(this, width, height, DEPTH_FORMAT);
		return depthTexture;
	}

	/**
	 * Clips later draws, in this and later passes, to a rectangle of the target (pixels from the top left). The rectangle is
	 * cut to the target, and an empty one clips everything.
	 */
	public function setScissorRectangle(x:Int, y:Int, width:Int, height:Int):Void {
		var left = Std.int(Math.max(0, x));
		var top = Std.int(Math.max(0, y));
		var right = Std.int(Math.min(targetWidth(), x + width));
		var bottom = Std.int(Math.min(targetHeight(), y + height));
		scissorEnabled = true;
		scissorX = left;
		scissorY = top;
		scissorWidth = Std.int(Math.max(0, right - left));
		scissorHeight = Std.int(Math.max(0, bottom - top));
		applyScissor();
	}

	/** Stops clipping draws. **/
	public function disableScissor():Void {
		scissorEnabled = false;
		applyScissor();
	}

	function applyScissor():Void {
		if (!passActive || wgpu.currentEncoder == null) return;
		if (scissorEnabled) {
			wgpu.currentEncoder.renderSetScissorRect(scissorX, scissorY, scissorWidth, scissorHeight);
		} else {
			wgpu.currentEncoder.renderSetScissorRect(0, 0, targetWidth(), targetHeight());
		}
	}

	public function endRenderPass():Void {
		if (!passActive) return;
		var enc = wgpu.currentEncoder;
		if (enc != null && enc.valid()) {
			enc.renderEnd();
		}
		passActive = false;
	}

	/**
	 * Draws indexed triangles using either `DisplayObjectShader` (when a texture is bound) or `GraphicsShader` (untextured).
	 */
	public function drawTriangles(
		indexBuffer:WgpuIndexBuffer3D,
		matrix:Matrix4,
		colorMultiplier:Array<Float> = null,
		colorOffset:Array<Float> = null,
		firstIndex:Int = 0,
		numTriangles:Int = -1
	):Void {
		var wasPassActive = passActive;
		if (!wasPassActive) {
			beginRenderPass(null);
		}

		var useTex = activeTexture != null;
		var shader = useTex ? displayObjectShader : graphicsShader;

		// Build vertex buffer layout from slot 0
		var vb0 = vertexBuffers.get(0);
		if (vb0 == null) return;

		var attrs:Array<VertexAttributeDesc> = [];
		for (loc => entry in vertexBuffers) {
			attrs.push({
				location: loc,
				offset: entry.offset,
				format: entry.format
			});
		}
		attrs.sort((a, b) -> a.location - b.location);

		var vbDesc:VertexBufferLayoutDesc = {
			stride: vb0.buffer.strideBytes,
			stepMode: VertexStepMode.Vertex,
			attributes: attrs
		};

		var pipeline = pipelineCache.getOrCreate({
			shader: shader,
			vsEntry: "vertex",
			fsEntry: "fragment",
			targetFormat: targetFormat(),
			blendEnabled: blendEnabled,
			srcRgb: srcRgb,
			dstRgb: dstRgb,
			opRgb: opRgb,
			srcAlpha: srcAlpha,
			dstAlpha: dstAlpha,
			opAlpha: opAlpha,
			colorWriteMask: colorWriteMask,
			depthWrite: depthWrite,
			depthCompare: depthCompare,
			depthFormat: depthEnabled ? DEPTH_FORMAT : null,
			topology: PrimitiveTopology.TriangleList,
			cullMode: cullMode,
			frontFace: frontFace,
			vertexBuffers: [vbDesc]
		});

		// Pack uniform block (`matrix` at 0, `colorMultiplier` at 64, `colorOffset` at 80 -> 96 bytes)
		var uboSize = useTex ? DisplayObjectShader.PARAMS_SIZE : GraphicsShader.PARAMS_SIZE;
		var uboBytes = Bytes.alloc(uboSize);
		uboBytes.blit(0, matrix.buffer, matrix.byteOffset, 64);

		var cmOff = useTex ? DisplayObjectShader.PARAMS_colorMultiplier : GraphicsShader.PARAMS_colorMultiplier;
		var coOff = useTex ? DisplayObjectShader.PARAMS_colorOffset : GraphicsShader.PARAMS_colorOffset;

		uboBytes.setFloat(cmOff, colorMultiplier != null && colorMultiplier.length > 0 ? colorMultiplier[0] : 1.0);
		uboBytes.setFloat(cmOff + 4, colorMultiplier != null && colorMultiplier.length > 1 ? colorMultiplier[1] : 1.0);
		uboBytes.setFloat(cmOff + 8, colorMultiplier != null && colorMultiplier.length > 2 ? colorMultiplier[2] : 1.0);
		uboBytes.setFloat(cmOff + 12, colorMultiplier != null && colorMultiplier.length > 3 ? colorMultiplier[3] : 1.0);

		uboBytes.setFloat(coOff, colorOffset != null && colorOffset.length > 0 ? colorOffset[0] : 0.0);
		uboBytes.setFloat(coOff + 4, colorOffset != null && colorOffset.length > 1 ? colorOffset[1] : 0.0);
		uboBytes.setFloat(coOff + 8, colorOffset != null && colorOffset.length > 2 ? colorOffset[2] : 0.0);
		uboBytes.setFloat(coOff + 12, colorOffset != null && colorOffset.length > 3 ? colorOffset[3] : 0.0);

		var dev = wgpu.device;
		var ubo = dev.createBuffer(new GpuBufferDescriptor(uboSize, BufferUsage.UNIFORM | BufferUsage.COPY_DST));
		wgpu.queue.writeBuffer(ubo, 0, uboBytes, uboSize);

		var bindings = new GpuBindings();
		bindings.buffer(ubo);
		if (useTex) {
			bindings.texture(activeTexture.view);
			var samp = repeat ? linearRepeatSampler : (smoothing ? linearClampSampler : nearestClampSampler);
			bindings.sampler(samp);
		}

		var bindGroup = dev.bindGroup(pipeline, 0, bindings);
		bindings.destroy();

		var enc = wgpu.currentEncoder;
		enc.renderSetPipeline(pipeline);
		enc.renderSetBindGroup(0, bindGroup);
		enc.renderSetVertexBuffer(0, vb0.buffer.gpuBuffer);
		enc.renderSetIndexBuffer(indexBuffer.gpuBuffer, IndexFormat.Uint16);
		vb0.buffer.storage.drawnFrame = frame;
		indexBuffer.storage.drawnFrame = frame;

		var indexCount = numTriangles >= 0 ? numTriangles * 3 : indexBuffer.numIndices - firstIndex;
		enc.renderDrawIndexedRange(indexCount, 1, firstIndex, 0, 0);

		if (!wasPassActive) {
			endRenderPass();
		}

		tempResources.push({buffers: [ubo], bindGroups: [bindGroup]});
	}

	/**
	 * Draws indexed triangles with `program`. Vertex buffers bind to the shader's inputs by attribute location
	 * (`setVertexBufferAt`), and textures by the order the shader declares them (`setTextureAt`). A slot with no texture
	 * reads white. The uniform block is the program's `params` as they are now.
	 */
	public function drawProgram(indexBuffer:WgpuIndexBuffer3D, firstIndex:Int = 0, numTriangles:Int = -1):Void {
		var program = this.program;
		if (program == null || indexBuffer == null) return;

		var locations = [for (location in vertexBuffers.keys()) location];
		locations.sort((a, b) -> a - b);
		var buffers:Array<WgpuVertexBuffer3D> = [];
		var vbDescs:Array<VertexBufferLayoutDesc> = [];
		for (location in locations) {
			var entry = vertexBuffers.get(location);
			var slot = buffers.indexOf(entry.buffer);
			if (slot < 0) {
				slot = buffers.length;
				buffers.push(entry.buffer);
				vbDescs.push({stride: entry.buffer.strideBytes, stepMode: VertexStepMode.Vertex, attributes: []});
			}
			vbDescs[slot].attributes.push({location: location, offset: entry.offset, format: entry.format});
		}
		if (buffers.length == 0) return;

		var wasPassActive = passActive;
		if (!wasPassActive) beginRenderPass(null);

		var layout = program.layout;
		var pipeline = pipelineCache.getOrCreate({
			shader: shader(layout.key, layout.wgsl),
			vsEntry: "vertex",
			fsEntry: "fragment",
			targetFormat: targetFormat(),
			blendEnabled: blendEnabled,
			srcRgb: srcRgb,
			dstRgb: dstRgb,
			opRgb: opRgb,
			srcAlpha: srcAlpha,
			dstAlpha: dstAlpha,
			opAlpha: opAlpha,
			colorWriteMask: colorWriteMask,
			depthWrite: depthWrite,
			depthCompare: depthCompare,
			depthFormat: depthEnabled ? DEPTH_FORMAT : null,
			topology: PrimitiveTopology.TriangleList,
			cullMode: cullMode,
			frontFace: frontFace,
			vertexBuffers: vbDescs
		});

		var dev = wgpu.device;
		var bindings = new GpuBindings();
		var tempBuffers:Array<GpuBuffer> = [];
		if (layout.paramsSize > 0) {
			var ubo = dev.createBuffer(new GpuBufferDescriptor(layout.paramsSize, BufferUsage.UNIFORM | BufferUsage.COPY_DST));
			wgpu.queue.writeBuffer(ubo, 0, program.params, layout.paramsSize);
			bindings.buffer(ubo);
			tempBuffers.push(ubo);
		}
		for (i in 0...layout.textures.length) {
			var texture = textureSlots[i];
			var wrap = slotRepeat[i] != null ? slotRepeat[i] : repeat;
			var smooth = slotSmooth[i] != null ? slotSmooth[i] : smoothing;
			bindings.texture((texture != null ? texture : whiteTexture()).view);
			bindings.sampler(wrap ? linearRepeatSampler : (smooth ? linearClampSampler : nearestClampSampler));
		}

		var bindGroup = dev.bindGroup(pipeline, 0, bindings);
		bindings.destroy();

		var enc = wgpu.currentEncoder;
		enc.renderSetPipeline(pipeline);
		enc.renderSetBindGroup(0, bindGroup);
		for (slot in 0...buffers.length) {
			enc.renderSetVertexBuffer(slot, buffers[slot].gpuBuffer);
			buffers[slot].storage.drawnFrame = frame;
		}
		enc.renderSetIndexBuffer(indexBuffer.gpuBuffer, IndexFormat.Uint16);
		indexBuffer.storage.drawnFrame = frame;
		var indexCount = numTriangles >= 0 ? numTriangles * 3 : indexBuffer.numIndices - firstIndex;
		enc.renderDrawIndexedRange(indexCount, 1, firstIndex, 0, 0);

		if (!wasPassActive) endRenderPass();

		tempResources.push({buffers: tempBuffers, bindGroups: [bindGroup]});
	}

	var white:Null<WgpuTexture>;

	function whiteTexture():WgpuTexture {
		if (white == null) {
			white = new WgpuTexture(this, 1, 1);
			var pixel = Bytes.alloc(4);
			pixel.fill(0, 4, 255);
			white.uploadFromBytes(pixel);
		}
		return white;
	}

	/**
	 * Instanced `drawQuads` / `Tilemap` fast-path using `InstancedQuadShader` and a GPU storage buffer.
	 * Each quad in `instanceData` is 12 floats (3 Vec4s):
	 *   [a, b, c, d, tx, ty, uvX, uvY, uvW, uvH, alpha, reserved]
	 */
	public function drawQuadsInstanced(
		texture:WgpuTexture,
		projection:Matrix4,
		instanceData:Float32Array,
		quadCount:Int,
		offsets:Bool = false,
		custom:Null<CustomQuadShader> = null,
		params:Null<Bytes> = null
	):Void {
		if (texture == null || quadCount <= 0) return;

		var wasPassActive = passActive;
		if (!wasPassActive) {
			beginRenderPass(null);
		}

		var pipeline = pipelineCache.getOrCreate({
			shader: custom != null ? shader(custom.key, custom.wgsl) : (offsets ? shader("offsetQuad", OffsetQuadShader.WGSL) : instancedQuadShader),
			vsEntry: "vertex",
			fsEntry: "fragment",
			targetFormat: targetFormat(),
			blendEnabled: blendEnabled,
			srcRgb: srcRgb,
			dstRgb: dstRgb,
			opRgb: opRgb,
			srcAlpha: srcAlpha,
			dstAlpha: dstAlpha,
			opAlpha: opAlpha,
			colorWriteMask: colorWriteMask,
			depthWrite: depthWrite,
			depthCompare: depthCompare,
			depthFormat: depthEnabled ? DEPTH_FORMAT : null,
			topology: PrimitiveTopology.TriangleList,
			cullMode: CullMode.None,
			frontFace: FrontFace.Ccw,
			vertexBuffers: []
		});

		var dev = wgpu.device;
		var uboSize = custom != null ? custom.paramsSize : (offsets ? OffsetQuadShader.PARAMS_SIZE : InstancedQuadShader.PARAMS_SIZE);
		var uboBytes = Bytes.alloc(uboSize);
		if (custom != null && params != null) uboBytes.blit(0, params, 0, uboSize);
		var projectionAt = custom != null ? custom.projectionAt : 0;
		var premultipliedAt = custom != null ? custom.premultipliedAt : (offsets ? OffsetQuadShader.PARAMS_premultiplied : InstancedQuadShader.PARAMS_premultiplied);
		if (projectionAt >= 0) uboBytes.blit(projectionAt, projection.buffer, projection.byteOffset, 64);
		if (premultipliedAt >= 0) uboBytes.setFloat(premultipliedAt, quadsPremultiplied ? 1.0 : 0.0);
		var ubo = dev.createBuffer(new GpuBufferDescriptor(uboSize, BufferUsage.UNIFORM | BufferUsage.COPY_DST));
		wgpu.queue.writeBuffer(ubo, 0, uboBytes, uboSize);

		var storageByteLen = quadCount * (offsets ? 80 : 48); // 3 or 5 Vec4 (16 bytes) per quad
		var storageBuf = dev.createBuffer(new GpuBufferDescriptor(storageByteLen, BufferUsage.STORAGE | BufferUsage.COPY_DST));
		var rawInstBytes = instanceData.byteOffset == 0 ? instanceData.buffer : instanceData.buffer.sub(instanceData.byteOffset, storageByteLen);
		wgpu.queue.writeBuffer(storageBuf, 0, rawInstBytes, storageByteLen);

		var bindings = new GpuBindings();
		bindings.buffer(ubo);
		bindings.texture(texture.view);
		bindings.sampler(smoothing ? linearClampSampler : nearestClampSampler);
		bindings.buffer(storageBuf);

		var bindGroup = dev.bindGroup(pipeline, 0, bindings);
		bindings.destroy();

		var enc = wgpu.currentEncoder;
		enc.renderSetPipeline(pipeline);
		enc.renderSetBindGroup(0, bindGroup);
		enc.renderDraw(6, quadCount);

		if (!wasPassActive) {
			endRenderPass();
		}

		tempResources.push({buffers: [ubo, storageBuf], bindGroups: [bindGroup]});
	}

	/**
	 * Draws a triangle list of `TriangleBatcher` vertices (24 bytes: position, uvt, color) textured with `texture`. Vertices
	 * append to one buffer per frame, so a draw never rewrites what an earlier draw this frame reads.
	 */
	public function drawTexturedTriangles(texture:WgpuTexture, repeat:Bool, projection:Matrix4, vertices:Bytes, length:Int):Void {
		if (texture == null || length < 72) return;
		var wasPassActive = passActive;
		if (!wasPassActive) beginRenderPass(null);

		var dev = wgpu.device;
		if (triangleFrame != frame) {
			triangleFrame = frame;
			triangleUsed = 0;
		}
		if (triangleBuffer == null || triangleUsed + length > triangleCapacity) {
			if (triangleBuffer != null) retire(triangleBuffer);
			triangleCapacity = Std.int(Math.max(triangleCapacity * 2, length + (length >> 1)));
			triangleBuffer = dev.createBuffer(new GpuBufferDescriptor(triangleCapacity, BufferUsage.VERTEX | BufferUsage.COPY_DST));
			triangleUsed = 0;
		}
		wgpu.queue.writeBuffer(triangleBuffer, triangleUsed, vertices, length);

		var pipeline = pipelineCache.getOrCreate({
			shader: shader("texturedTriangle", TexturedTriangleShader.WGSL),
			vsEntry: "vertex",
			fsEntry: "fragment",
			targetFormat: targetFormat(),
			blendEnabled: blendEnabled,
			srcRgb: srcRgb,
			dstRgb: dstRgb,
			opRgb: opRgb,
			srcAlpha: srcAlpha,
			dstAlpha: dstAlpha,
			opAlpha: opAlpha,
			colorWriteMask: colorWriteMask,
			depthWrite: false,
			depthCompare: CompareFunction.Always,
			depthFormat: depthEnabled ? DEPTH_FORMAT : null,
			topology: PrimitiveTopology.TriangleList,
			cullMode: CullMode.None,
			frontFace: FrontFace.Ccw,
			vertexBuffers: [{
				stride: 24,
				stepMode: VertexStepMode.Vertex,
				attributes: [
					{location: 0, offset: 0, format: VertexFormat.Float32x2},
					{location: 1, offset: 8, format: VertexFormat.Float32x3},
					{location: 2, offset: 20, format: VertexFormat.Unorm8x4}
				]
			}]
		});

		var uboSize = TexturedTriangleShader.PARAMS_SIZE;
		var uboBytes = Bytes.alloc(uboSize);
		uboBytes.blit(TexturedTriangleShader.PARAMS_matrix, projection.buffer, projection.byteOffset, 64);
		uboBytes.setFloat(TexturedTriangleShader.PARAMS_premultiplied, trianglesPremultiplied ? 1.0 : 0.0);
		var ubo = dev.createBuffer(new GpuBufferDescriptor(uboSize, BufferUsage.UNIFORM | BufferUsage.COPY_DST));
		wgpu.queue.writeBuffer(ubo, 0, uboBytes, uboSize);

		var bindings = new GpuBindings();
		bindings.buffer(ubo);
		bindings.texture(texture.view);
		bindings.sampler(repeat ? linearRepeatSampler : (smoothing ? linearClampSampler : nearestClampSampler));
		var bindGroup = dev.bindGroup(pipeline, 0, bindings);
		bindings.destroy();

		var enc = wgpu.currentEncoder;
		enc.renderSetPipeline(pipeline);
		enc.renderSetBindGroup(0, bindGroup);
		enc.renderSetVertexBuffer(0, triangleBuffer);
		enc.renderDrawRange(Std.int(length / 24), 1, Std.int(triangleUsed / 24), 0);
		triangleUsed += length;

		if (!wasPassActive) endRenderPass();
		tempResources.push({buffers: [ubo], bindGroups: [bindGroup]});
	}

	/**
	 * Draws `vertexCount` vertices of a `puffpuff.canvas.Mesh` layout buffer (32-byte stride:
	 * `head` vec4 @0, `edges` vec4 @16) with `VectorPathShader`, reading paints from `paints` (storage).
	 */
	public function drawVectorMesh(vertices:GpuBuffer, vertexCount:Int, paints:GpuBuffer, matrix:Matrix4, firstVertex:Int = 0, paintBase:Int = 0):Void {
		if (vertexCount <= 0) return;
		var wasPassActive = passActive;
		if (!wasPassActive) beginRenderPass(null);

		var vs = shader("vectorPath", VectorPathShader.WGSL);
		var pipeline = pipelineCache.getOrCreate({
			shader: vs,
			vsEntry: "vertex",
			fsEntry: "fragment",
			targetFormat: targetFormat(),
			blendEnabled: blendEnabled,
			srcRgb: srcRgb,
			dstRgb: dstRgb,
			opRgb: opRgb,
			srcAlpha: srcAlpha,
			dstAlpha: dstAlpha,
			opAlpha: opAlpha,
			colorWriteMask: ColorWrite.ALL,
			depthWrite: false,
			depthCompare: CompareFunction.Always,
			depthFormat: depthEnabled ? DEPTH_FORMAT : null,
			topology: PrimitiveTopology.TriangleList,
			cullMode: CullMode.None,
			frontFace: FrontFace.Ccw,
			vertexBuffers: [{
				stride: 32,
				stepMode: VertexStepMode.Vertex,
				attributes: [
					{location: 0, offset: 0, format: VertexFormat.Float32x4},
					{location: 1, offset: 16, format: VertexFormat.Float32x4}
				]
			}]
		});

		var dev = wgpu.device;
		var uboSize = VectorPathShader.PARAMS_SIZE;
		var uboBytes = Bytes.alloc(uboSize);
		uboBytes.blit(VectorPathShader.PARAMS_matrix, matrix.buffer, matrix.byteOffset, 64);
		uboBytes.setFloat(VectorPathShader.PARAMS_paintBase, paintBase);
		uboBytes.setFloat(VectorPathShader.PARAMS_premultiply, vectorsPremultiplied ? 1.0 : 0.0);
		var ubo = dev.createBuffer(new GpuBufferDescriptor(uboSize, BufferUsage.UNIFORM | BufferUsage.COPY_DST));
		wgpu.queue.writeBuffer(ubo, 0, uboBytes, uboSize);

		var bindings = new GpuBindings();
		bindings.buffer(ubo);
		bindings.buffer(paints);
		var bindGroup = dev.bindGroup(pipeline, 0, bindings);
		bindings.destroy();

		var enc = wgpu.currentEncoder;
		enc.renderSetPipeline(pipeline);
		enc.renderSetBindGroup(0, bindGroup);
		enc.renderSetVertexBuffer(0, vertices);
		enc.renderDrawRange(vertexCount, 1, firstVertex, 0);

		if (!wasPassActive) endRenderPass();
		tempResources.push({buffers: [ubo], bindGroups: [bindGroup]});
	}

	/**
	 * Full-screen triangle pass of an effect shader declaring `@param effect:Vec4` then `@param source:Sampler2D`,
	 * into the current target. `additive` blends One/One; otherwise replaces.
	 */
	public function drawFullscreen(effectShader:GpuShader, uboSize:Int, effectOffset:Int, source:WgpuTexture, e0:Float, e1:Float, e2:Float, e3:Float,
			additive:Bool = false):Void {
		var wasPassActive = passActive;
		if (!wasPassActive) beginRenderPass(null);

		var pipeline = pipelineCache.getOrCreate({
			shader: effectShader,
			vsEntry: "vertex",
			fsEntry: "fragment",
			targetFormat: targetFormat(),
			blendEnabled: additive,
			srcRgb: BlendFactor.One,
			dstRgb: additive ? BlendFactor.One : BlendFactor.Zero,
			opRgb: BlendOperation.Add,
			srcAlpha: BlendFactor.One,
			dstAlpha: additive ? BlendFactor.One : BlendFactor.Zero,
			opAlpha: BlendOperation.Add,
			colorWriteMask: ColorWrite.ALL,
			depthWrite: false,
			depthCompare: CompareFunction.Always,
			depthFormat: depthEnabled ? DEPTH_FORMAT : null,
			topology: PrimitiveTopology.TriangleList,
			cullMode: CullMode.None,
			frontFace: FrontFace.Ccw,
			vertexBuffers: []
		});

		var dev = wgpu.device;
		var uboBytes = Bytes.alloc(uboSize);
		uboBytes.setFloat(effectOffset, e0);
		uboBytes.setFloat(effectOffset + 4, e1);
		uboBytes.setFloat(effectOffset + 8, e2);
		uboBytes.setFloat(effectOffset + 12, e3);
		var ubo = dev.createBuffer(new GpuBufferDescriptor(uboSize, BufferUsage.UNIFORM | BufferUsage.COPY_DST));
		wgpu.queue.writeBuffer(ubo, 0, uboBytes, uboSize);

		var bindings = new GpuBindings();
		bindings.buffer(ubo);
		bindings.texture(source.view);
		bindings.sampler(linearClampSampler);
		var bindGroup = dev.bindGroup(pipeline, 0, bindings);
		bindings.destroy();

		var enc = wgpu.currentEncoder;
		enc.renderSetPipeline(pipeline);
		enc.renderSetBindGroup(0, bindGroup);
		enc.renderDraw(3, 1);

		if (!wasPassActive) endRenderPass();
		tempResources.push({buffers: [ubo], bindGroups: [bindGroup]});
	}

	/** Destroys `buffer` after this frame is submitted, since recorded commands may still read it. **/
	public inline function retire(buffer:GpuBuffer):Void {
		tempResources.push({buffers: [buffer], bindGroups: []});
	}

	/** Called after the frame's encoder is submitted. Starts a new `frame`. **/
	public function flushTempResources():Void {
		frame++;
		for (res in tempResources) {
			for (bg in res.bindGroups) {
				if (bg.valid()) bg.destroy();
			}
			for (buf in res.buffers) {
				if (buf.valid()) buf.destroy();
			}
		}
		tempResources.resize(0);
		for (texture in retiredTextures) texture.dispose();
		retiredTextures.resize(0);
	}

	public function dispose():Void {
		if (triangleBuffer != null) retire(triangleBuffer);
		triangleBuffer = null;
		flushTempResources();
		pipelineCache.clear();
		if (graphicsShader.valid()) graphicsShader.destroy();
		if (displayObjectShader.valid()) displayObjectShader.destroy();
		if (bitmapFillShader.valid()) bitmapFillShader.destroy();
		if (alphaMaskShader.valid()) alphaMaskShader.destroy();
		if (instancedQuadShader.valid()) instancedQuadShader.destroy();
		if (white != null) white.dispose();
		for (s in lazyShaders) if (s.valid()) s.destroy();
		lazyShaders.clear();
		if (linearClampSampler.valid()) linearClampSampler.destroy();
		if (nearestClampSampler.valid()) nearestClampSampler.destroy();
		if (linearRepeatSampler.valid()) linearRepeatSampler.destroy();
	}
}
