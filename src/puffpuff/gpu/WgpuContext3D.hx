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

/**
 * Hardware WebGPU VertexBuffer3D backed by `gpu.GpuBuffer`.
 */
class WgpuVertexBuffer3D {
	public var context(default, null):WgpuContext3D;
	public var numVertices(default, null):Int;
	public var strideFloats(default, null):Int;
	public var strideBytes(default, null):Int;
	public var gpuBuffer(default, null):GpuBuffer;

	public function new(context:WgpuContext3D, numVertices:Int, data32PerVertex:Int) {
		this.context = context;
		this.numVertices = numVertices;
		this.strideFloats = data32PerVertex;
		this.strideBytes = data32PerVertex * 4;
		var byteSize:haxe.Int64 = Std.int(Math.max(16, numVertices * strideBytes));
		this.gpuBuffer = context.wgpu.device.createBuffer(
			new GpuBufferDescriptor(byteSize, BufferUsage.VERTEX | BufferUsage.COPY_DST)
		);
	}

	public function uploadFromBytes(data:Bytes, startVertex:Int = 0, count:Int = -1):Void {
		if (data == null) return;
		var len = count > 0 ? count * strideBytes : data.length;
		var offset:haxe.Int64 = startVertex * strideBytes;
		context.wgpu.queue.writeBuffer(gpuBuffer, offset, data, len);
	}

	public function uploadFromFloat32Array(data:Float32Array, startVertex:Int = 0, count:Int = -1):Void {
		if (data == null) return;
		var bytes = data.byteOffset == 0 ? data.buffer : data.buffer.sub(data.byteOffset, data.byteLength);
		uploadFromBytes(bytes, startVertex, count);
	}

	public function dispose():Void {
		if (gpuBuffer.valid()) gpuBuffer.destroy();
	}
}

/**
 * Hardware WebGPU IndexBuffer3D backed by `gpu.GpuBuffer`.
 */
class WgpuIndexBuffer3D {
	public var context(default, null):WgpuContext3D;
	public var numIndices(default, null):Int;
	public var gpuBuffer(default, null):GpuBuffer;

	public function new(context:WgpuContext3D, numIndices:Int) {
		this.context = context;
		this.numIndices = numIndices;
		// WebGPU requires writeBuffer size to be a multiple of 4 bytes.
		var byteSize:haxe.Int64 = (numIndices * 2 + 3) & ~3;
		if (byteSize < 4) byteSize = 4;
		this.gpuBuffer = context.wgpu.device.createBuffer(
			new GpuBufferDescriptor(byteSize, BufferUsage.INDEX | BufferUsage.COPY_DST)
		);
	}

	public function uploadFromBytes(data:Bytes, startOffset:Int = 0, count:Int = -1):Void {
		if (data == null) return;
		var rawLen = count > 0 ? count * 2 : data.length;
		var alignedLen = (rawLen + 3) & ~3;
		var uploadData = data;
		if (data.length < alignedLen) {
			uploadData = Bytes.alloc(alignedLen);
			uploadData.blit(0, data, 0, data.length);
		}
		var offset:haxe.Int64 = startOffset * 2;
		context.wgpu.queue.writeBuffer(gpuBuffer, offset, uploadData, alignedLen);
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
		if (gpuBuffer.valid()) gpuBuffer.destroy();
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
			TextureUsage.TEXTURE_BINDING | TextureUsage.COPY_DST | TextureUsage.RENDER_ATTACHMENT | TextureUsage.COPY_SRC
		));
		this.view = this.gpuTexture.createView(new GpuTextureViewDescriptor());
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
			TextureUsage.TEXTURE_BINDING | TextureUsage.COPY_DST | TextureUsage.RENDER_ATTACHMENT | TextureUsage.COPY_SRC
		));
		this.view = this.gpuTexture.createView(new GpuTextureViewDescriptor());
	}

	public function uploadFromUInt8Array(data:UInt8Array):Void {
		if (data == null) return;
		uploadFromBytes(data.toBytes(), width * 4);
	}

	public function uploadFromImage(image:Image):Void {
		if (image == null || image.data == null) return;
		uploadFromBytes(image.data, image.width * 4);
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

	// Tracked Context3D state
	public var blendEnabled:Bool = true;
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

	private var currentShader:GpuShader;
	private var activeTexture:Null<WgpuTexture>;
	private var vertexBuffers:Map<Int, {buffer:WgpuVertexBuffer3D, offset:Int, format:VertexFormat}>;
	private var passActive:Bool = false;
	private var tempResources:Array<{buffers:Array<GpuBuffer>, bindGroups:Array<GpuBindGroup>}>;

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

	public function setTextureAt(samplerSlot:Int, texture:Null<WgpuTexture>):Void {
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

	public function beginRenderPass(clearR:Null<Float> = null, clearG:Float = 0.0, clearB:Float = 0.0, clearA:Float = 1.0):Void {
		if (passActive) return;
		var enc = wgpu.currentEncoder;
		var view = wgpu.currentView;
		if (enc == null || view == null) return;

		enc.passReset();
		if (clearR != null) {
			enc.passColour(view, clearR, clearG, clearB, clearA);
		} else {
			// Load existing contents of the render target (`NaN` clear in hlwgpu loads instead of clearing, or we clear at start)
			enc.passColour(view, Math.NaN, 0, 0, 0);
		}
		enc.passBegin();
		enc.renderSetViewport(0, 0, wgpu.width, wgpu.height, 0.0, 1.0);
		passActive = true;
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
			targetFormat: wgpu.surfaceFormat,
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
			depthFormat: null,
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

		var indexCount = numTriangles >= 0 ? numTriangles * 3 : indexBuffer.numIndices - firstIndex;
		enc.renderDrawIndexed(indexCount, 1);

		if (!wasPassActive) {
			endRenderPass();
		}

		tempResources.push({buffers: [ubo], bindGroups: [bindGroup]});
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
		quadCount:Int
	):Void {
		if (texture == null || quadCount <= 0) return;

		var wasPassActive = passActive;
		if (!wasPassActive) {
			beginRenderPass(null);
		}

		var pipeline = pipelineCache.getOrCreate({
			shader: instancedQuadShader,
			vsEntry: "vertex",
			fsEntry: "fragment",
			targetFormat: wgpu.surfaceFormat,
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
			depthFormat: null,
			topology: PrimitiveTopology.TriangleList,
			cullMode: CullMode.None,
			frontFace: FrontFace.Ccw,
			vertexBuffers: []
		});

		var dev = wgpu.device;
		var uboSize = InstancedQuadShader.PARAMS_SIZE;
		var uboBytes = Bytes.alloc(uboSize);
		uboBytes.blit(0, projection.buffer, projection.byteOffset, 64);
		var ubo = dev.createBuffer(new GpuBufferDescriptor(uboSize, BufferUsage.UNIFORM | BufferUsage.COPY_DST));
		wgpu.queue.writeBuffer(ubo, 0, uboBytes, uboSize);

		var storageByteLen = quadCount * 48; // 3 * Vec4 (16 bytes) = 48 bytes per quad
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

	public function flushTempResources():Void {
		for (res in tempResources) {
			for (bg in res.bindGroups) {
				if (bg.valid()) bg.destroy();
			}
			for (buf in res.buffers) {
				if (buf.valid()) buf.destroy();
			}
		}
		tempResources.resize(0);
	}

	public function dispose():Void {
		flushTempResources();
		pipelineCache.clear();
		if (graphicsShader.valid()) graphicsShader.destroy();
		if (displayObjectShader.valid()) displayObjectShader.destroy();
		if (bitmapFillShader.valid()) bitmapFillShader.destroy();
		if (alphaMaskShader.valid()) alphaMaskShader.destroy();
		if (instancedQuadShader.valid()) instancedQuadShader.destroy();
		if (linearClampSampler.valid()) linearClampSampler.destroy();
		if (nearestClampSampler.valid()) nearestClampSampler.destroy();
		if (linearRepeatSampler.valid()) linearRepeatSampler.destroy();
	}
}
