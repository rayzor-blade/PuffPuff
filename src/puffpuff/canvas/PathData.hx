package puffpuff.canvas;

/** One absolute outline step. SVG's relative/H/V/S/T forms are normalised into these. **/
enum PathCommand {
	MoveTo(x:Float, y:Float);
	LineTo(x:Float, y:Float);
	CubicTo(x1:Float, y1:Float, x2:Float, y2:Float, x:Float, y:Float);
	QuadTo(x1:Float, y1:Float, x:Float, y:Float);

	/** Elliptical arc; `rotation` in degrees. **/
	ArcTo(rx:Float, ry:Float, rotation:Float, largeArc:Bool, sweep:Bool, x:Float, y:Float);

	Close;
}

/** SVG path-data (`d` attribute) reader. Throws a `String` at the first malformed token. **/
class PathData {
	public static function parse(d:String):Array<PathCommand>
		return new PathReader(d).read();
}

private class PathReader {
	final d:String;
	var i = 0;
	final out:Array<PathCommand> = [];
	var x = 0.0;
	var y = 0.0;
	var startX = 0.0;
	var startY = 0.0;
	// Last control point, for S/T reflection; NaN = none.
	var lastCubicX = Math.NaN;
	var lastCubicY = Math.NaN;
	var lastQuadX = Math.NaN;
	var lastQuadY = Math.NaN;

	public function new(d:String) {
		this.d = d;
	}

	public function read():Array<PathCommand> {
		skip();
		if (i < d.length && d.charAt(i) != "M" && d.charAt(i) != "m")
			fail("a path starts with M");
		var command = "";
		while (true) {
			skip();
			if (i >= d.length)
				break;
			var c = d.charAt(i);
			if (isCommand(c)) {
				command = c;
				i++;
			} else if (command == "" || command == "Z" || command == "z") {
				fail('expected a command, not "$c"');
			}
			step(command);
			// Implicit coordinate pairs after M are lines.
			if (command == "M")
				command = "L";
			else if (command == "m")
				command = "l";
		}
		return out;
	}

	function step(command:String):Void {
		var relative = command.toLowerCase() == command;
		var ox = relative ? x : 0.0;
		var oy = relative ? y : 0.0;
		var cx = Math.NaN, cy = Math.NaN, qx = Math.NaN, qy = Math.NaN;
		switch command.toUpperCase() {
			case "M":
				x = ox + number();
				y = oy + number();
				startX = x;
				startY = y;
				out.push(MoveTo(x, y));
			case "L":
				x = ox + number();
				y = oy + number();
				out.push(LineTo(x, y));
			case "H":
				x = ox + number();
				out.push(LineTo(x, y));
			case "V":
				y = oy + number();
				out.push(LineTo(x, y));
			case "C":
				var x1 = ox + number(), y1 = oy + number();
				var x2 = ox + number(), y2 = oy + number();
				x = ox + number();
				y = oy + number();
				out.push(CubicTo(x1, y1, x2, y2, x, y));
				cx = x2;
				cy = y2;
			case "S":
				var x1 = Math.isNaN(lastCubicX) ? x : 2 * x - lastCubicX;
				var y1 = Math.isNaN(lastCubicY) ? y : 2 * y - lastCubicY;
				var x2 = ox + number(), y2 = oy + number();
				x = ox + number();
				y = oy + number();
				out.push(CubicTo(x1, y1, x2, y2, x, y));
				cx = x2;
				cy = y2;
			case "Q":
				var x1 = ox + number(), y1 = oy + number();
				x = ox + number();
				y = oy + number();
				out.push(QuadTo(x1, y1, x, y));
				qx = x1;
				qy = y1;
			case "T":
				var x1 = Math.isNaN(lastQuadX) ? x : 2 * x - lastQuadX;
				var y1 = Math.isNaN(lastQuadY) ? y : 2 * y - lastQuadY;
				x = ox + number();
				y = oy + number();
				out.push(QuadTo(x1, y1, x, y));
				qx = x1;
				qy = y1;
			case "A":
				var rx = Math.abs(number()), ry = Math.abs(number());
				var rotation = number();
				var large = flag(), sweep = flag();
				x = ox + number();
				y = oy + number();
				out.push(ArcTo(rx, ry, rotation, large, sweep, x, y));
			case "Z":
				x = startX;
				y = startY;
				out.push(Close);
			case _:
				fail('unknown command "$command"');
		}
		lastCubicX = cx;
		lastCubicY = cy;
		lastQuadX = qx;
		lastQuadY = qy;
	}

	static inline function isCommand(c:String):Bool
		return "MmLlHhVvCcSsQqTtAaZz".indexOf(c) >= 0;

	/** Whitespace and at most one comma. **/
	function skip():Void {
		var comma = false;
		while (i < d.length) {
			var c = d.charCodeAt(i);
			if (c == " ".code || c == "\t".code || c == "\n".code || c == "\r".code || c == 0x0C) {
				i++;
			} else if (c == ",".code && !comma) {
				comma = true;
				i++;
			} else {
				break;
			}
		}
	}

	/** Arc flags are single 0/1 digits and may abut the next number. **/
	function flag():Bool {
		skip();
		var c = i < d.length ? d.charAt(i) : "";
		if (c != "0" && c != "1")
			fail("an arc flag is 0 or 1");
		i++;
		return c == "1";
	}

	function number():Float {
		skip();
		var start = i;
		if (i < d.length && (d.charAt(i) == "+" || d.charAt(i) == "-"))
			i++;
		var digits = 0;
		while (i < d.length && isDigit(d.charCodeAt(i))) {
			i++;
			digits++;
		}
		if (i < d.length && d.charAt(i) == ".") {
			i++;
			while (i < d.length && isDigit(d.charCodeAt(i))) {
				i++;
				digits++;
			}
		}
		if (digits == 0)
			fail(i >= d.length ? "the path ends mid-command" : 'expected a number at "${d.substr(start, 8)}"');
		if (i < d.length && (d.charAt(i) == "e" || d.charAt(i) == "E")) {
			var mark = i;
			i++;
			if (i < d.length && (d.charAt(i) == "+" || d.charAt(i) == "-"))
				i++;
			if (i < d.length && isDigit(d.charCodeAt(i))) {
				while (i < d.length && isDigit(d.charCodeAt(i)))
					i++;
			} else {
				i = mark;
			}
		}
		return Std.parseFloat(d.substring(start, i));
	}

	static inline function isDigit(c:Int):Bool
		return c >= "0".code && c <= "9".code;

	function fail(message:String):Dynamic {
		throw 'path data, at $i: $message';
	}
}

