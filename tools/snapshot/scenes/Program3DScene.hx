import puffpuff.snapshot.Snapshot;

/**
 * Lit 3D meshes through `drawProgram` with an HXSL program (see `Meshes3D`): a torus with a sphere in its hole, and a
 * textured cube, seen through a perspective camera. Also renders a few frames of them turning.
 */
class Program3DScene {
	static inline var W = 480;
	static inline var H = 300;
	static inline var BACKGROUND = 0x141724;

	static function draw(c3d:puffpuff.gpu.WgpuContext3D, angle:Float):Void {
		c3d.depthEnabled = true;
		c3d.beginRenderPass(0.08, 0.09, 0.14, 1.0, 1.0);
		Meshes3D.draw(c3d, angle, W / H);
		c3d.endRenderPass();
	}

	static function main() {
		var path = Snapshot.scene("program3d-scene", W, H, ctx -> draw(ctx.wgpu.context3D, 0.4), BACKGROUND);

		var failures = [];
		function at(p:{x:Int, y:Int}):Int {
			var i = (p.y * W + p.x) * 4;
			return (Snapshot.pixels.get(i) << 16) | (Snapshot.pixels.get(i + 1) << 8) | Snapshot.pixels.get(i + 2);
		}
		function brightness(rgb:Int):Int
			return ((rgb >> 16) & 0xFF) + ((rgb >> 8) & 0xFF) + (rgb & 0xFF);
		var sphere = Meshes3D.project(Meshes3D.LEFT, 0, Meshes3D.Z, W, H), cube = Meshes3D.project(Meshes3D.RIGHT, 0, Meshes3D.Z, W, H);
		if (at({x: 5, y: 5}) != BACKGROUND) failures.push("background is not clear");
		if (at(sphere) == BACKGROUND) failures.push("sphere is not drawn");
		if (at(cube) == BACKGROUND) failures.push("cube is not drawn");
		// The light comes from the upper left, so the sphere is brighter there than at the lower right.
		var lit = at({x: sphere.x - 12, y: sphere.y - 12}), dark = at({x: sphere.x + 12, y: sphere.y + 12});
		if (brightness(lit) <= brightness(dark) + 20) failures.push('sphere is not lit from the upper left (${StringTools.hex(lit, 6)} vs ${StringTools.hex(dark, 6)})');
		// The torus is in front of the sphere at its rim, which a flat painter's order could not get right.
		var rim = Meshes3D.project(Meshes3D.LEFT, 0.55, Meshes3D.Z - 0.4, W, H);
		if (at(rim) == at(sphere)) failures.push("torus does not cross in front of the sphere");

		Snapshot.sequence("program3d-spin", W, H, (frame, dt, ctx) -> draw(ctx.wgpu.context3D, 0.4 + frame * 0.5), 30, 4, BACKGROUND);

		if (failures.length > 0) throw 'Program3D scene wrong: ${failures.join(", ")}';
		Sys.println('Program3D draw ok $path');
	}
}
