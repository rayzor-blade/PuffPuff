import lime.utils.Float32Array;

/**
 * Indexed triangle meshes with 8 floats a vertex (position, normal, uv), and the matrices a 3D scene needs. Matrices
 * are 16 floats in the layout an HXSL `vec4 * mat4` reads: translation at 3, 7 and 11, the way `Matrix4.createOrtho`
 * stores it. Depth runs 0 to 1, as WebGPU's does.
 */
class Mesh3D {
	public final vertices:Float32Array;
	public final indices:Array<Int>;

	public function new(vertices:Array<Float>, indices:Array<Int>) {
		this.vertices = new Float32Array(vertices);
		this.indices = indices;
	}

	public static function torus(radius:Float, tube:Float, rings:Int, sides:Int):Mesh3D {
		var v = [], i = [];
		for (a in 0...rings + 1) {
			var u = a / rings * 2 * Math.PI;
			for (b in 0...sides + 1) {
				var w = b / sides * 2 * Math.PI;
				var nx = Math.cos(w) * Math.cos(u), ny = Math.sin(w), nz = Math.cos(w) * Math.sin(u);
				v.push((radius + tube * Math.cos(w)) * Math.cos(u));
				v.push(tube * Math.sin(w));
				v.push((radius + tube * Math.cos(w)) * Math.sin(u));
				v.push(nx);
				v.push(ny);
				v.push(nz);
				v.push(a / rings * 4);
				v.push(b / sides);
			}
		}
		grid(i, rings, sides);
		return new Mesh3D(v, i);
	}

	public static function sphere(radius:Float, rings:Int, sides:Int):Mesh3D {
		var v = [], i = [];
		for (a in 0...rings + 1) {
			var phi = a / rings * Math.PI;
			for (b in 0...sides + 1) {
				var theta = b / sides * 2 * Math.PI;
				var nx = Math.sin(phi) * Math.cos(theta), ny = Math.cos(phi), nz = Math.sin(phi) * Math.sin(theta);
				v.push(radius * nx);
				v.push(radius * ny);
				v.push(radius * nz);
				v.push(nx);
				v.push(ny);
				v.push(nz);
				v.push(b / sides);
				v.push(a / rings);
			}
		}
		grid(i, rings, sides);
		return new Mesh3D(v, i);
	}

	public static function cube(half:Float):Mesh3D {
		var v = [], i = [];
		// Each face: its normal, then two edge directions that run along u and v.
		var faces = [
			[0, 0, -1, 1, 0, 0, 0, 1, 0],
			[0, 0, 1, -1, 0, 0, 0, 1, 0],
			[1, 0, 0, 0, 0, 1, 0, 1, 0],
			[-1, 0, 0, 0, 0, -1, 0, 1, 0],
			[0, 1, 0, 1, 0, 0, 0, 0, 1],
			[0, -1, 0, 1, 0, 0, 0, 0, -1]
		];
		for (f in faces) {
			var base = Std.int(v.length / 8);
			for (corner in [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
				var s = corner[0], t = corner[1];
				v.push(half * (f[0] + s * f[3] + t * f[6]));
				v.push(half * (f[1] + s * f[4] + t * f[7]));
				v.push(half * (f[2] + s * f[5] + t * f[8]));
				v.push(f[0]);
				v.push(f[1]);
				v.push(f[2]);
				v.push((s + 1) / 2);
				v.push(1 - (t + 1) / 2);
			}
			i.push(base);
			i.push(base + 1);
			i.push(base + 2);
			i.push(base);
			i.push(base + 2);
			i.push(base + 3);
		}
		return new Mesh3D(v, i);
	}

	/** Two triangles a cell of a `rings` by `sides` grid of `sides + 1` vertices a row, wound clockwise seen from outside. **/
	static function grid(i:Array<Int>, rings:Int, sides:Int):Void {
		for (a in 0...rings)
			for (b in 0...sides) {
				var p = a * (sides + 1) + b, q = p + sides + 1;
				i.push(p);
				i.push(q);
				i.push(p + 1);
				i.push(p + 1);
				i.push(q);
				i.push(q + 1);
			}
	}

	public static function identity():Float32Array
		return new Float32Array([1., 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

	/** `a` first, then `b`. **/
	public static function mul(a:Float32Array, b:Float32Array):Float32Array {
		var m = new Float32Array(16);
		for (r in 0...4)
			for (c in 0...4) {
				var sum = 0.0;
				for (k in 0...4) sum += b[r * 4 + k] * a[k * 4 + c];
				m[r * 4 + c] = sum;
			}
		return m;
	}

	public static function rotateX(angle:Float):Float32Array {
		var m = identity(), c = Math.cos(angle), s = Math.sin(angle);
		m[5] = c;
		m[6] = -s;
		m[9] = s;
		m[10] = c;
		return m;
	}

	public static function rotateY(angle:Float):Float32Array {
		var m = identity(), c = Math.cos(angle), s = Math.sin(angle);
		m[0] = c;
		m[2] = s;
		m[8] = -s;
		m[10] = c;
		return m;
	}

	public static function translate(x:Float, y:Float, z:Float):Float32Array {
		var m = identity();
		m[3] = x;
		m[7] = y;
		m[11] = z;
		return m;
	}

	/** Camera at the origin looking down +z. **/
	public static function perspective(fovY:Float, aspect:Float, near:Float, far:Float):Float32Array {
		var f = 1 / Math.tan(fovY / 2);
		var m = new Float32Array(16);
		m[0] = f / aspect;
		m[5] = f;
		m[10] = far / (far - near);
		m[11] = -near * far / (far - near);
		m[14] = 1;
		return m;
	}
}
