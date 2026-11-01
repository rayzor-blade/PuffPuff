import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.display.Application;
import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.events.Event;
import puffpuff.snapshot.Headless;

/**
 * A plain HaxeFlixel game, FlxGame with a state, a sprite and a text, rendered through OpenFL on PuffPuff. HaxeFlixel finds its
 * own version through `haxelib path flixel`, so flixel must be registered (`haxelib dev flixel <checkout>`). Needs OpenFL with
 * `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu -cp <flixel> -D flixel=6.2.0 -D FLX_STANDARD_ASSETS_DIRECTORY" \
 *     tools/snapshot/run.sh tools/snapshot/scenes/FlxGameScene.hx
 */
@:access(openfl.display.DisplayObject)
class FlxGameScene {
	static inline var W = 320;
	static inline var H = 240;

	static function main():Void {
		var result = Headless.render("flixel-game-scene", W, H, () -> {
			var app = new Application();
			app.onUpdate.add(_ -> Sys.sleep(0.02));
			var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: 0x000000}});
			DisplayObject.__initStage = window.stage;
			var root = new Game();
			window.stage.addChild(root);
			root.dispatchEvent(new Event(Event.ADDED_TO_STAGE, false, false));
			return app;
		}, 1.0, 40);

		function at(x:Int, y:Int):Int {
			var i = (y * W + x) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		var failures = [];
		if (at(5, 5) != 0x223344) failures.push('state color at 5,5 is ${StringTools.hex(at(5, 5), 6)}');
		if (at(70, 70) != 0xFFA500) failures.push('sprite at 70,70 is ${StringTools.hex(at(70, 70), 6)}');
		var lit = 0;
		for (y in 120...150)
			for (x in 40...280)
				if (at(x, y) != 0x223344) lit++;
		if (lit < 200) failures.push('text drew only $lit pixels');
		if (failures.length > 0) throw 'Flixel game render wrong: ${failures.join(", ")}';
		Sys.println("Flixel game render ok");
		Sys.exit(0);
	}
}

class Game extends Sprite {
	public function new() {
		super();
		addChild(new FlxGame(320, 240, Play, 60, 60, true));
	}
}

class Play extends FlxState {
	override public function create():Void {
		super.create();
		bgColor = 0xFF223344;
		var box = new FlxSprite(40, 40);
		box.makeGraphic(64, 64, FlxColor.ORANGE);
		add(box);
		add(new FlxText(40, 120, 240, "HaxeFlixel on PuffPuff", 16));
	}
}
