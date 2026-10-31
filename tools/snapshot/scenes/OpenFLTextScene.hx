import openfl.display.Application;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import puffpuff.snapshot.Headless;
import puffpuff.text.FontAtlas;

/**
 * OpenFL `TextField`s on a headless window through `openfl.display.WgpuRenderer`, at display scales 1 and 2:
 * plain, wrapped, bold, italic, serif and monospace text, a background and border, colored ranges, alignment and
 * mixed scripts, and once more with the opt-in hinted advances. The checks compare the ink drawn with the layout OpenFL computed. Needs OpenFL with `-D openfl_wgpu`:
 *
 *   PUFFPUFF_HAXE_FLAGS="-cp ../openfl/src -D openfl=9.5.2 -D openfl_wgpu" tools/snapshot/run.sh tools/snapshot/scenes/OpenFLTextScene.hx
 */
class OpenFLTextScene {
	static inline var W = 480;
	static inline var H = 270;
	static inline var BACKGROUND = 0x14181F;

	static var fields:Map<String, TextField> = new Map();

	static function field(name:String, x:Float, y:Float, text:String, font:String, size:Int, color:Int, ?bold:Bool, ?italic:Bool):TextField {
		var tf = new TextField();
		tf.defaultTextFormat = new TextFormat(font, size, color, bold, italic);
		tf.selectable = false;
		tf.autoSize = TextFieldAutoSize.LEFT;
		tf.x = x;
		tf.y = y;
		tf.text = text;
		fields.set(name, tf);
		return tf;
	}

	static function build():Application {
		var app = new Application();
		var window:openfl.display.Window = cast app.createWindow({width: W, height: H, context: {background: BACKGROUND}});
		var stage:openfl.display.DisplayObjectContainer = window.stage;
		fields = new Map();

		stage.addChild(field("title", 10, 8, "Hello, OpenFL", "_sans", 24, 0xFFFFFF));

		var paragraph = field("paragraph", 10, 44, "The quick brown fox jumps over the lazy dog while the five boxing wizards jump quickly, and pack my box with five dozen liquor jugs.",
			"_sans", 14, 0xCCCCCC);
		paragraph.wordWrap = true;
		paragraph.autoSize = TextFieldAutoSize.NONE;
		paragraph.width = 300;
		paragraph.height = 60;
		stage.addChild(paragraph);

		stage.addChild(field("bold", 330, 10, "Bold text", "_sans", 16, 0xFFDD33, true));
		stage.addChild(field("italic", 330, 34, "Italic text", "_sans", 16, 0x33DDFF, false, true));
		stage.addChild(field("serif", 330, 58, "Serif text", "_serif", 16, 0xFFFFFF));
		stage.addChild(field("mono", 330, 82, "Monospace 0123", "_typewriter", 14, 0x66FF99));

		var boxed = field("boxed", 10, 118, "Boxed text", "_sans", 16, 0xFFFFFF);
		boxed.autoSize = TextFieldAutoSize.NONE;
		boxed.width = 160;
		boxed.height = 28;
		boxed.background = true;
		boxed.backgroundColor = 0x203060;
		boxed.border = true;
		boxed.borderColor = 0x8888FF;
		stage.addChild(boxed);

		var ranges = field("ranges", 190, 120, "Red and blue words", "_sans", 16, 0xFFFFFF);
		ranges.setTextFormat(new TextFormat(null, null, 0xFF3030), 0, 3);
		ranges.setTextFormat(new TextFormat(null, null, 0x6699FF), 8, 12);
		stage.addChild(ranges);

		var aligned:Array<{name:String, align:TextFormatAlign, x:Float}> = [
			{name: "center", align: TextFormatAlign.CENTER, x: 10},
			{name: "right", align: TextFormatAlign.RIGHT, x: 250}
		];
		for (item in aligned)
		{
			var tf = field(item.name, item.x, 160, "aligned", "_sans", 16, 0xFFFFFF);
			tf.defaultTextFormat = new TextFormat("_sans", 16, 0xFFFFFF, null, null, null, null, null, item.align);
			tf.autoSize = TextFieldAutoSize.NONE;
			tf.width = 220;
			tf.height = 26;
			tf.border = true;
			tf.borderColor = 0x555555;
			tf.text = "aligned";
			stage.addChild(tf);
		}

		stage.addChild(field("scripts", 10, 200, "Hello 你好 こんにちは 안녕 ★ ✓", "_sans", 18, 0xFFFFFF));
		stage.addChild(field("small", 10, 232, "Twelve pixel text, the quick brown fox jumps over the lazy dog", "_sans", 12, 0x99A0AA));

		return app;
	}

	static function main():Void {
		check("openfl-text-scene-1x", 1.0);
		check("openfl-text-scene", 2.0);
		// Opt-in hinted layout, which is how OpenFL native lays text out by default: whole-pixel advances.
		FontAtlas.hintedAdvances = true;
		check("openfl-text-scene-hinted-1x", 1.0);
		FontAtlas.hintedAdvances = false;
		Sys.println("OpenFL text render ok");
	}

	static function check(name:String, scale:Float):Void {
		var result = Headless.render(name, W, H, build, scale);
		var failures = [];
		function pixel(x:Int, y:Int):Int {
			var i = (y * result.width + x) * 4;
			return (result.pixels.get(i) << 16) | (result.pixels.get(i + 1) << 8) | result.pixels.get(i + 2);
		}
		function distance(a:Int, b:Int):Int {
			return Std.int(Math.max(Math.abs(((a >> 16) & 0xFF) - ((b >> 16) & 0xFF)), Math.max(Math.abs(((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)), Math.abs((a & 0xFF) - (b & 0xFF)))));
		}
		/** The bounding box of what differs from the background inside `tf`'s rectangle, in logical pixels, and the most distant pixel. **/
		function ink(tf:TextField, inset = 0):{left:Float, right:Float, top:Float, bottom:Float, extreme:Int, count:Int} {
			var x0 = Std.int((tf.x + inset) * scale), y0 = Std.int((tf.y + inset) * scale);
			var x1 = Std.int((tf.x + tf.width - inset) * scale), y1 = Std.int((tf.y + tf.height - inset) * scale);
			var box = {left: 1e9, right: -1e9, top: 1e9, bottom: -1e9, extreme: BACKGROUND, count: 0};
			var best = 0;
			for (y in y0...y1)
				for (x in x0...x1) {
					var p = pixel(x, y);
					var d = distance(p, BACKGROUND);
					if (d > 40) {
						box.count++;
						box.left = Math.min(box.left, x / scale);
						box.right = Math.max(box.right, (x + 1) / scale);
						box.top = Math.min(box.top, y / scale);
						box.bottom = Math.max(box.bottom, (y + 1) / scale);
						if (d > best) {
							best = d;
							box.extreme = p;
						}
					}
				}
			return box;
		}
		function colour(label:String, got:Int, want:Int, tolerance = 40):Void {
			if (distance(got, want) > tolerance) failures.push('$label colour ${StringTools.hex(got, 6)} not ${StringTools.hex(want, 6)}');
		}
		// The ink of a field stays inside the text the layout measured, and spans most of it.
		function extent(label:String, tf:TextField, want:Int):Void {
			var box = ink(tf);
			if (box.count < 20) {
				failures.push('$label has almost no ink (${box.count} pixels)');
				return;
			}
			var width = box.right - box.left;
			if (width > tf.textWidth + 2 || width < tf.textWidth * 0.85) failures.push('$label ink is ${width} px wide, layout says ${tf.textWidth}');
			colour(label, box.extreme, want, 60);
		}

		extent("title", fields.get("title"), 0xFFFFFF);
		extent("paragraph", fields.get("paragraph"), 0xCCCCCC);
		extent("bold", fields.get("bold"), 0xFFDD33);
		extent("italic", fields.get("italic"), 0x33DDFF);
		extent("serif", fields.get("serif"), 0xFFFFFF);
		extent("mono", fields.get("mono"), 0x66FF99);
		extent("small", fields.get("small"), 0x99A0AA);
		extent("scripts", fields.get("scripts"), 0xFFFFFF);

		// The paragraph wraps onto the lines the layout found.
		var paragraph = fields.get("paragraph");
		var lines = ink(paragraph);
		if (paragraph.numLines < 3 || lines.bottom - lines.top < 2 * 14) failures.push('paragraph has ${paragraph.numLines} lines and ink ${lines.bottom - lines.top} px high');

		// Background and border.
		var boxed = fields.get("boxed");
		colour("background", pixel(Std.int((boxed.x + boxed.width - 6) * scale), Std.int((boxed.y + 6) * scale)), 0x203060, 8);
		colour("border", pixel(Std.int((boxed.x + 80) * scale), Std.int(boxed.y * scale)), 0x8888FF, 60);

		// Colored ranges: a red pixel among the first letters, a blue one near the end.
		var ranges = fields.get("ranges");
		var red = false, blue = false;
		for (y in Std.int(ranges.y * scale)...Std.int((ranges.y + ranges.height) * scale))
			for (x in Std.int(ranges.x * scale)...Std.int((ranges.x + ranges.width) * scale)) {
				var p = pixel(x, y);
				if (distance(p, 0xFF3030) < 60) red = true;
				if (distance(p, 0x6699FF) < 60) blue = true;
			}
		if (!red) failures.push("no red pixel in the red range");
		if (!blue) failures.push("no blue pixel in the blue range");

		// Alignment: centered ink sits in the middle of its field, right aligned ink at its right edge.
		var center = fields.get("center"), right = fields.get("right");
		var c = ink(center, 2), r = ink(right, 2);
		if (Math.abs((c.left + c.right) / 2 - (center.x + center.width / 2)) > 4) failures.push('centred text is at ${(c.left + c.right) / 2}, field centre ${center.x + center.width / 2}');
		if (Math.abs(r.right - (right.x + right.width - 2)) > 5) failures.push('right aligned text ends at ${r.right}, field edge ${right.x + right.width - 2}');

		if (failures.length > 0) throw 'OpenFL text render wrong at ${scale}x: ${failures.join(", ")}';
	}
}
