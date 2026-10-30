import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
	OpenFL's own text path, timed to compare with PuffPuff's text cases in tools/bench: wrapped paragraphs, a static screen
	of labels, and the same labels with their text set every frame. Prints `<key> <value>` lines for run.sh.
**/
class Main extends Sprite {
	static inline var LABELS = 200;
	static inline var WARMUP = 30;
	static inline var FRAMES = 300;
	static inline var PARAGRAPHS = 500;

	var labels:Array<TextField> = [];
	var phase = 0;
	var frame = 0;
	var start = 0.0;
	var counter = 0;

	public function new() {
		super();
		layout();
		var format = new TextFormat("_sans", 14, 0xFFFFFF);
		for (i in 0...LABELS) {
			var tf = new TextField();
			tf.defaultTextFormat = format;
			tf.selectable = false;
			tf.width = 180;
			tf.height = 20;
			tf.x = (i % 4) * 190 + 10;
			tf.y = Std.int(i / 4) * 11 + 4;
			tf.text = "Label " + i + ": the quick brown fox";
			addChild(tf);
			labels.push(tf);
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function layout():Void {
		var format = new TextFormat("_sans", 14, 0xFFFFFF);
		var paragraph = "The quick brown fox jumps over the lazy dog while the five boxing wizards jump quickly, and pack my box with five dozen liquor jugs. ";
		var t0 = haxe.Timer.stamp();
		for (i in 0...PARAGRAPHS) {
			var tf = new TextField();
			tf.defaultTextFormat = format;
			tf.wordWrap = true;
			tf.width = 300;
			tf.text = paragraph + i;
			var lines = tf.numLines;
			var width = tf.textWidth;
		}
		var dt = haxe.Timer.stamp() - t0;
		Sys.println("layout.paragraph.us " + dt / PARAGRAPHS * 1e6);

		// The layout result, so another backend can show it did the same work.
		var tf = new TextField();
		tf.defaultTextFormat = format;
		tf.wordWrap = true;
		tf.width = 300;
		tf.text = paragraph + 0;
		Sys.println("check.paragraph.lines " + tf.numLines);
		Sys.println("check.paragraph.textWidth " + tf.textWidth);
		Sys.println("check.paragraph.textHeight " + tf.textHeight);
	}

	function onFrame(_):Void {
		frame++;
		if (frame == WARMUP) start = haxe.Timer.stamp();
		if (phase == 1) {
			for (tf in labels) tf.text = "Label " + (counter++) + ": the quick brown fox";
		}
		if (frame == WARMUP + FRAMES) {
			var ms = (haxe.Timer.stamp() - start) / FRAMES * 1000;
			Sys.println((phase == 0 ? "frame.static.ms " : "frame.dynamic.ms ") + ms);
			if (phase == 0) {
				phase = 1;
				frame = 0;
			} else {
				Sys.exit(0);
			}
		}
	}
}
