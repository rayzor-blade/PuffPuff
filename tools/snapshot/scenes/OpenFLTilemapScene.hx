import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.Tile;
import openfl.display.TileContainer;
import openfl.display.Tilemap;
import openfl.display.Tileset;
import openfl.geom.Rectangle;
import puffpuff.snapshot.Headless;

/**
 * An OpenFL `Tilemap` on a headless window through `openfl.display.WgpuRenderer`, at display scales 1 and 2: tiles at
 * positions, scaled, turned, half transparent, in a nested container, and clipped to the tilemap's size. Needs OpenFL
 * with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLTilemapScene.hx
 */
class OpenFLTilemapScene {
	static inline var W = 160;
	static inline var H = 120;
	static inline var BACKGROUND = 0x14181F;

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;

		// Four 32 x 32 tiles on one sheet: red, green, blue, yellow.
		var sheet = new BitmapData(64, 64, true, 0xFFFF0000);
		sheet.fillRect(new Rectangle(32, 0, 32, 32), 0xFF00FF00);
		sheet.fillRect(new Rectangle(0, 32, 32, 32), 0xFF0000FF);
		sheet.fillRect(new Rectangle(32, 32, 32, 32), 0xFFFFFF00);
		var tileset = new Tileset(sheet, [new Rectangle(0, 0, 32, 32), new Rectangle(32, 0, 32, 32), new Rectangle(0, 32, 32, 32), new Rectangle(32, 32, 32, 32)]);

		var map = new Tilemap(130, 100, tileset, false);
		map.x = 10;
		map.y = 10;
		map.addTile(new Tile(0, 0, 0));
		map.addTile(new Tile(1, 40, 0));
		map.addTile(new Tile(0, 110, 0, 1, 1, 90));
		map.addTile(new Tile(2, 0, 40, 2, 2));
		var faded = new Tile(3, 70, 40);
		faded.alpha = 0.5;
		map.addTile(faded);
		var group = new TileContainer(70, 76);
		group.addTile(new Tile(0, 0, 0));
		group.addTile(new Tile(1, 36, 0));
		map.addTile(group);
		stage.addChild(map);
		return app;
	}

	static function main():Void {
		check("openfl-tilemap-scene-1x", 1.0);
		check("openfl-tilemap-scene", 2.0);
		Sys.println("OpenFL tilemap render ok");
	}

	static function check(name:String, scale:Float):Void {
		var result = Headless.render(name, W, H, build, scale);
		var failures = [];
		function at(x:Float, y:Float):Int {
			var i = (Std.int(y * scale) * result.width + Std.int(x * scale)) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		function expect(label:String, x:Float, y:Float, rgb:Int, tolerance = 6):Void {
			var got = at(x, y);
			if (Math.abs(((got >> 16) & 0xFF) - ((rgb >> 16) & 0xFF)) > tolerance || Math.abs(((got >> 8) & 0xFF) - ((rgb >> 8) & 0xFF)) > tolerance
				|| Math.abs((got & 0xFF) - (rgb & 0xFF)) > tolerance)
				failures.push('$label ${StringTools.hex(got, 6)} not ${StringTools.hex(rgb, 6)}');
		}

		expect("red", 10 + 16, 10 + 16, 0xFF0000);
		expect("green", 10 + 56, 10 + 16, 0x00FF00);
		expect("between green and the turned red", 10 + 75, 10 + 16, BACKGROUND);
		expect("turned red", 10 + 94, 10 + 16, 0xFF0000);
		expect("doubled blue", 10 + 32, 10 + 70, 0x0000FF);
		expect("doubled blue, at its right edge", 10 + 62, 10 + 70, 0x0000FF);
		expect("beyond the doubled blue", 10 + 68, 10 + 70, BACKGROUND);
		expect("doubled blue cut at the tilemap's bottom", 10 + 32, 10 + 98, 0x0000FF);
		expect("below the tilemap", 10 + 32, 10 + 104, BACKGROUND);
		expect("half transparent yellow", 10 + 86, 10 + 56, 0x898B0F, 8);
		expect("container red", 10 + 80, 10 + 84, 0xFF0000);
		expect("container green inside", 10 + 125, 10 + 84, 0x00FF00);
		expect("container green cut at the right edge", 10 + 135, 10 + 84, BACKGROUND);

		if (failures.length > 0) throw 'OpenFL tilemap render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
