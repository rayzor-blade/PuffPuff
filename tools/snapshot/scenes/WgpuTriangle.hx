import gpu.BufferUsage;
import gpu.GpuBufferDescriptor;
import gpu.GpuRenderPipelineDescriptor;
import gpu.GpuVertexState;
import gpu.GpuFragmentState;
import gpu.GpuColorTargetState;
import gpu.GpuPrimitiveState;
import gpu.PrimitiveTopology;
import puffpuff.snapshot.Snapshot;

/**
 * Snapshot scene testing offscreen WGPU rendering and WGSL triangle shader pipeline.
 */
class WgpuTriangle {
	static final SHADER_WGSL = "
struct VertexOut {
	@builtin(position) pos: vec4<f32>,
	@location(0) color: vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VertexOut {
	var positions = array<vec2<f32>, 3>(
		vec2<f32>( 0.0,  0.65),
		vec2<f32>(-0.65, -0.65),
		vec2<f32>( 0.65, -0.65)
	);
	var colors = array<vec4<f32>, 3>(
		vec4<f32>(1.0, 0.35, 0.35, 1.0),
		vec4<f32>(0.25, 0.90, 0.55, 1.0),
		vec4<f32>(0.30, 0.55, 1.0,  1.0)
	);
	var out: VertexOut;
	out.pos = vec4<f32>(positions[idx], 0.0, 1.0);
	out.color = colors[idx];
	return out;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4<f32> {
	return in.color;
}
";

	static function main() {
		Snapshot.scene("wgpu-triangle", 480, 320, ctx -> {
			var wgpu = ctx.wgpu;
			var dev = wgpu.device;

			var shader = dev.createShader(SHADER_WGSL);
			var vs = new GpuVertexState(shader);
			vs.entryPoint("vs_main");

			var fs = new GpuFragmentState(shader);
			fs.entryPoint("fs_main");
			fs.addTargets(new GpuColorTargetState(wgpu.surfaceFormat));

			var desc = new GpuRenderPipelineDescriptor(vs);
			desc.fragment(fs);
			var prim = new GpuPrimitiveState();
			prim.topology(PrimitiveTopology.TriangleList);
			desc.primitive(prim);

			var pipeline = dev.createRenderPipeline(desc);

			var enc = wgpu.currentEncoder;
			enc.passReset();
			enc.passColour(wgpu.currentView, 0.08, 0.10, 0.16, 1.0);
			enc.passBegin();
			enc.renderSetViewport(0, 0, wgpu.width, wgpu.height, 0.0, 1.0);
			enc.renderSetPipeline(pipeline);
			enc.renderDraw(3, 1);
			enc.renderEnd();

			pipeline.destroy();
			shader.destroy();
		}, 0x141A29);
	}
}

