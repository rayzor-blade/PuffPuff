import openfl.display.Application;
import openfl.display.Sprite;
import openfl.geom.Point;
import openfl.Vector;
import puffpuff.snapshot.Headless;

/**
 * Shape hit testing (`hitTestPoint` with `shapeFlag`) through openfl.display._internal.WgpuGraphics.hitTest: fills by their
 * outline whatever their alpha, holes by the even-odd rule, strokes by their width, triangles, and under a transform. Prints
 * "OpenFL hit test checks passed" or throws. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLHitTestCheck.hx
 */
class OpenFLHitTestCheck {
	static var failures:Array<String> = [];

	static function expect(name:String, sprite:Sprite, x:Float, y:Float, hit:Bool):Void {
		var got = sprite.hitTestPoint(x, y, true);
		if (got != hit) failures.push('$name at $x,$y: ${got ? "hit" : "miss"}, expected ${hit ? "hit" : "miss"}');
	}

	static function main():Void {
		Headless.render("openfl-hit-test", 200, 200, () -> {
			var app = new Application();
			var window:openfl.display.Window = cast app.createWindow({width: 200, height: 200});
			var stage:openfl.display.DisplayObjectContainer = window.stage;

			// A disc: its bounds corner is outside it.
			var disc = new Sprite();
			disc.graphics.beginFill(0xFF0000);
			disc.graphics.drawCircle(50, 50, 40);
			disc.graphics.endFill();
			stage.addChild(disc);
			expect("disc center", disc, 50, 50, true);
			expect("disc edge inside", disc, 85, 50, true);
			expect("disc bounds corner", disc, 15, 15, false);
			expect("outside bounds", disc, 150, 50, false);

			// A fill with no alpha still takes the mouse, as in Flash.
			var clear = new Sprite();
			clear.graphics.beginFill(0x000000, 0);
			clear.graphics.drawRect(0, 0, 40, 40);
			clear.graphics.endFill();
			clear.x = 100;
			stage.addChild(clear);
			expect("transparent fill", clear, 120, 20, true);

			// A ring: two circles in one fill, the inner one a hole.
			var ring = new Sprite();
			ring.graphics.beginFill(0x00FF00);
			ring.graphics.drawCircle(50, 50, 40);
			ring.graphics.drawCircle(50, 50, 20);
			ring.graphics.endFill();
			ring.y = 100;
			stage.addChild(ring);
			expect("ring body", ring, 50 + 30, 150, true);
			expect("ring hole", ring, 50, 150, false);

			// A stroke only: hit within half the width of the line.
			var line = new Sprite();
			line.graphics.lineStyle(10, 0x0000FF);
			line.graphics.moveTo(0, 0);
			line.graphics.lineTo(100, 0);
			line.x = 100;
			line.y = 100;
			stage.addChild(line);
			expect("on the line", line, 150, 100, true);
			expect("within the width", line, 150, 104, true);
			expect("beyond the width", line, 150, 107, false);

			// Triangles: inside one, in the gap between two.
			var mesh = new Sprite();
			mesh.graphics.beginFill(0xFFFFFF);
			mesh.graphics.drawTriangles(Vector.ofArray([0.0, 0, 30, 0, 0, 30, 60, 0, 90, 0, 60, 30]));
			mesh.graphics.endFill();
			mesh.x = 100;
			mesh.y = 150;
			stage.addChild(mesh);
			expect("triangle", mesh, 105, 155, true);
			expect("gap", mesh, 145, 175, false);

			// A scaled and moved shape: the point is mapped back into its own units.
			var scaled = new Sprite();
			scaled.graphics.beginFill(0xFFFF00);
			scaled.graphics.drawCircle(10, 10, 10);
			scaled.graphics.endFill();
			scaled.scaleX = 3;
			scaled.scaleY = 3;
			scaled.x = 0;
			scaled.y = 0;
			stage.addChild(scaled);
			expect("scaled inside", scaled, 30, 30, true);
			expect("scaled outside the circle", scaled, 3, 3, false);
			return app;
		}, 1.0, 2);
		if (failures.length > 0) throw 'OpenFL hit test wrong: ${failures.join("; ")}';
		Sys.println("OpenFL hit test checks passed");
	}
}
