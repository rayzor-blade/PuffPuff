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
		/** Added to each vertex's `paint`. Where this draw's records start in `paints`. **/
		@param var paintBase:Float;
		/** 1 writes color scaled by its alpha, for blend modes that take a premultiplied source. **/
		@param var premultiply:Float;
		@param var paints:StorageBuffer<Vec4>;
		var pixel:Vec2;
		var coverage:Float;
		var paint:Float;
		var edgeDist:Vec4;

		function vertex() {
			pixel = input.head.xy;
			coverage = input.head.z;
			paint = input.head.w + paintBase;
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
				var map = paints[at + 1];
				var offsets = paints[at + 2];
				var origin = paints[at + 7];
				var u = vec2(map.x * pixel.x + map.z * pixel.y + origin.x, map.y * pixel.x + map.w * pixel.y + origin.y);
				var t = u.x;
				if (head.x > 1.5)
					t = length(u);
				if (origin.z > 1.5)
					t = t - floor(t);
				else if (origin.z > 0.5)
					t = 1.0 - abs(t - 2.0 * floor(t * 0.5) - 1.0);
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
			var alpha = color.a * head.z * covered;
			output.color = vec4(color.rgb, alpha);
			if (premultiply > 0.5)
				output.color = vec4(color.rgb * alpha, alpha);
		}
	};
}

