import openfl.text.AntiAliasType;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import puffpuff.text.FontAtlas;

/**
 * Checks the opt-in hinted advances against widths measured on OpenFL 9.5.2 native (hxcpp, macOS, 14 px `_sans`, one
 * line, `textWidth`): with `FontAtlas.hintedAdvances` off the layout is exact; on, it matches OpenFL's hinted layout; and
 * text set to `ADVANCED` anti-aliasing at sharpness 400 is unhinted either way, as it is on OpenFL. Needs OpenFL with
 * `-D openfl_wgpu`. Prints "text hint checks passed" or throws.
 */
class TextHintCheck {
	static function fail(message:String):Void {
		throw 'text hint check failed: $message';
	}

	static function width(text:String, ?antiAlias:AntiAliasType, sharpness = 0.0):Float {
		var tf = new TextField();
		tf.defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF);
		if (antiAlias != null) tf.antiAliasType = antiAlias;
		tf.sharpness = sharpness;
		tf.autoSize = TextFieldAutoSize.LEFT;
		tf.text = text;
		return tf.textWidth;
	}

	static function expect(label:String, got:Float, want:Float, tolerance:Float):Void {
		if (Math.abs(got - want) > tolerance) fail('$label is $got, OpenFL native has $want');
	}

	static function main():Void {
		var paragraph = "The quick brown fox jumps over the lazy dog while the five boxing wizards jump quickly, and pack my box with five dozen liquor jugs. 0";
		// Widths from OpenFL native: hinted (the default, anti-aliasing NORMAL) and unhinted (ADVANCED, sharpness 400).
		var hinted:Array<{text:String, width:Float}> = [
			{text: "a", width: 8}, {text: "i", width: 3}, {text: "m", width: 12}, {text: "W", width: 13}, {text: " ", width: 4},
			{text: "To", width: 15.453125}, {text: "AV", width: 16.96875}, {text: "The quick brown fox", width: 128},
			{text: "The quick brown fox jumps over the lazy dog ", width: 287}
		];
		var unhinted:Array<{text:String, width:Float}> = [
			{text: "a", width: 7.78125}, {text: "m", width: 11.65625}, {text: "To", width: 14.78125}, {text: "AV", width: 17.65625},
			{text: "The quick brown fox", width: 125.234375}, {text: "The quick brown fox jumps over the lazy dog ", width: 280.8125}
		];

		FontAtlas.hintedAdvances = false;
		for (u in unhinted) expect('exact "${u.text}"', width(u.text), u.width, 0.15);
		var exactParagraph = wrapped(paragraph).textWidth;
		var exactLines = wrapped(paragraph).numLines;

		FontAtlas.hintedAdvances = true;
		for (h in hinted) expect('hinted "${h.text}"', width(h.text), h.width, 0.02);
		for (u in unhinted) expect('ADVANCED 400 "${u.text}" with hinting on', width(u.text, AntiAliasType.ADVANCED, 400), u.width, 0.15);
		var paragraphField = wrapped(paragraph);
		expect("hinted benchmark paragraph", paragraphField.textWidth, 292.97, 0.05);
		if (paragraphField.numLines != 3) fail('the hinted paragraph has ${paragraphField.numLines} lines, OpenFL native 3');
		FontAtlas.hintedAdvances = false;

		Sys.println('exact paragraph width $exactParagraph in $exactLines lines, hinted 292.97 in 3 lines, as OpenFL native');
		Sys.println("text hint checks passed");
	}

	/** The benchmark field: word wrapped at 300 px. **/
	static function wrapped(text:String):TextField {
		var tf = new TextField();
		tf.defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF);
		tf.wordWrap = true;
		tf.width = 300;
		tf.text = text;
		return tf;
	}
}
