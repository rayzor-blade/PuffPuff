package puffpuff.gpu.shaders;

/**
 * Analytic-AA vector fill for `puffpuff.canvas.Canvas2D`. Vertex = `head (x, y, coverage, paint)` +
 * `edges (d0..d3)` in target pixels. Paint records (`puffpuff.canvas.Paint`, 8 × vec4) live in a
 * storage buffer indexed by `paint`. Gradients mix premultiplied, as CSS does.
 */
class VectorPathShader implements hlwgpu.hxsl.Shader {
	static var SRC = {
		@input var input:{
			head:Vec4,
			edges:Vec4
		};
		var output:{
			position:Vec4,
			color:Vec4
		};
		@param var matrix:Mat4;
		@param var paints:StorageBuffer<Vec4>;
		var pixel:Vec2;
		var coverage:Float;
		var paint:Float;
		var edgeDist:Vec4;

		function vertex() {
			pixel = input.head.xy;
			coverage = input.head.z;
			paint = input.head.w;
			edgeDist = input.edges;
			output.position = vec4(input.head.xy, 0.0, 1.0) * matrix;
		}

		function premultiplied(c:Vec4):Vec4 {
			return vec4(c.rgb * c.a, c.a);
		}

		function fragment() {
			var at = int(paint + 0.5) * 8;
			var head = paints[at];
			var color = paints[at + 3];
			if (head.x > 0.5) {
				var geo = paints[at + 1];
				var offsets = paints[at + 2];
				var t = 0.0;
				if (head.x < 1.5) {
					var d = geo.zw - geo.xy;
					t = dot(pixel - geo.xy, d) / max(dot(d, d), 0.000001);
				} else {
					t = length(pixel - geo.xy) / max(geo.z, 0.000001);
				}
				t = clamp(t, 0.0, 1.0);
				var p0 = premultiplied(paints[at + 3]);
				var p1 = premultiplied(paints[at + 4]);
				var p2 = premultiplied(paints[at + 5]);
				var p3 = premultiplied(paints[at + 6]);
				var mixed = p0;
				if (head.y > 1.5 && t > offsets.x)
					mixed = mix(p0, p1, clamp((t - offsets.x) / max(offsets.y - offsets.x, 0.000001), 0.0, 1.0));
				if (head.y > 2.5 && t > offsets.y)
					mixed = mix(p1, p2, clamp((t - offsets.y) / max(offsets.z - offsets.y, 0.000001), 0.0, 1.0));
				if (head.y > 3.5 && t > offsets.z)
					mixed = mix(p2, p3, clamp((t - offsets.z) / max(offsets.w - offsets.z, 0.000001), 0.0, 1.0));
				color = vec4(0.0, 0.0, 0.0, 0.0);
				if (mixed.a > 0.000001)
					color = vec4(mixed.rgb / mixed.a, mixed.a);
			}
			// Half a pixel inside every edge = fully covered; on the edge = half.
			var inside = clamp(edgeDist + vec4(0.5, 0.5, 0.5, 0.5), vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0));
			var covered = coverage * inside.x * inside.y * inside.z * inside.w;
			output.color = vec4(color.rgb, color.a * head.z * covered);
		}
	};
}

