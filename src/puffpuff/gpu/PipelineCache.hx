package puffpuff.gpu;

import gpu.BlendFactor;
import gpu.BlendOperation;
import gpu.ColorWrite;
import gpu.CompareFunction;
import gpu.CullMode;
import gpu.FrontFace;
import gpu.GpuDevice;
import gpu.GpuPipeline;
import gpu.GpuPipelineBuilder;
import gpu.GpuShader;
import gpu.PrimitiveTopology;
import gpu.TextureFormat;
import gpu.VertexFormat;
import gpu.VertexStepMode;

typedef VertexAttributeDesc = {
	var format:VertexFormat;
	var offset:Int;
	var location:Int;
}

typedef VertexBufferLayoutDesc = {
	var stride:Int;
	var stepMode:VertexStepMode;
	var attributes:Array<VertexAttributeDesc>;
}

typedef PipelineStateKey = {
	var shader:GpuShader;
	var vsEntry:String;
	var fsEntry:String;
	var targetFormat:TextureFormat;
	var blendEnabled:Bool;
	var srcRgb:BlendFactor;
	var dstRgb:BlendFactor;
	var opRgb:BlendOperation;
	var srcAlpha:BlendFactor;
	var dstAlpha:BlendFactor;
	var opAlpha:BlendOperation;
	var colorWriteMask:Int;
	var depthWrite:Bool;
	var depthCompare:CompareFunction;
	var depthFormat:Null<TextureFormat>;
	var topology:PrimitiveTopology;
	var cullMode:CullMode;
	var frontFace:FrontFace;
	var vertexBuffers:Array<VertexBufferLayoutDesc>;
}

/**
 * Caches immutable WebGPU `GpuPipeline` objects keyed by Context3D state hashes.
 */
class PipelineCache {
	private var device:GpuDevice;
	private var cache:Map<String, GpuPipeline>;

	public function new(device:GpuDevice) {
		this.device = device;
		this.cache = new Map<String, GpuPipeline>();
	}

	public function getOrCreate(state:PipelineStateKey):GpuPipeline {
		var key = hashKey(state);
		var existing = cache.get(key);
		if (existing != null && existing.valid()) {
			return existing;
		}

		var builder:GpuPipelineBuilder = device.pipeline();
		builder.shader(
			state.shader,
			state.vsEntry != null ? state.vsEntry : "vertex",
			state.fsEntry != null ? state.fsEntry : "fragment"
		);

		if (state.vertexBuffers != null) {
			for (vb in state.vertexBuffers) {
				builder.vertexBuffer(vb.stride, vb.stepMode);
				for (attr in vb.attributes) {
					builder.attribute(attr.format, attr.offset, attr.location);
				}
			}
		}

		var writeMask = state.colorWriteMask != 0 ? state.colorWriteMask : ColorWrite.ALL;
		builder.target(state.targetFormat, writeMask);

		if (state.blendEnabled) {
			builder.blend(
				state.srcRgb,
				state.dstRgb,
				state.opRgb,
				state.srcAlpha,
				state.dstAlpha,
				state.opAlpha
			);
		}

		if (state.depthFormat != null) {
			builder.depth(state.depthFormat, state.depthWrite, state.depthCompare);
		}

		builder.primitive(state.topology, state.cullMode, state.frontFace);

		var pipeline = builder.build();
		builder.destroy();
		cache.set(key, pipeline);
		return pipeline;
	}

	private static function hashKey(s:PipelineStateKey):String {
		var buf = new StringBuf();
		buf.add((s.shader : Int));
		buf.add(":");
		buf.add(s.vsEntry != null ? s.vsEntry : "vertex");
		buf.add(":");
		buf.add(s.fsEntry != null ? s.fsEntry : "fragment");
		buf.add(":");
		buf.add((s.targetFormat : Int));
		buf.add(":");
		buf.add(s.blendEnabled ? "1" : "0");
		if (s.blendEnabled) {
			buf.add(':${(s.srcRgb:Int)},${(s.dstRgb:Int)},${(s.opRgb:Int)},${(s.srcAlpha:Int)},${(s.dstAlpha:Int)},${(s.opAlpha:Int)}');
		}
		buf.add(':${s.colorWriteMask}:${s.depthWrite ? 1 : 0}:${(s.depthCompare:Int)}:${s.depthFormat != null ? (s.depthFormat:Int) : -1}');
		buf.add(':${(s.topology:Int)}:${(s.cullMode:Int)}:${(s.frontFace:Int)}');
		if (s.vertexBuffers != null) {
			for (vb in s.vertexBuffers) {
				buf.add('|vb:${vb.stride},${(vb.stepMode:Int)}');
				for (a in vb.attributes) {
					buf.add('[${a.location}:${(a.format:Int)}@${a.offset}]');
				}
			}
		}
		return buf.toString();
	}

	public function clear():Void {
		for (p in cache) {
			if (p.valid()) p.destroy();
		}
		cache.clear();
	}
}
