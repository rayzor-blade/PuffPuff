import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.text.TextField;

/** Touches the OpenFL display list so the compiler type-checks what a real program reaches. **/
class OpenFLSmoke extends Sprite {
	public function new() {
		super();
		var shape = new Shape();
		shape.graphics.beginFill(0xFF0000);
		shape.graphics.drawRect(0, 0, 100, 100);
		shape.graphics.endFill();
		addChild(shape);
		addChild(new Bitmap(new BitmapData(16, 16, true, 0xFFFFFFFF)));
		var text = new TextField();
		text.text = "hello";
		addChild(text);
	}

	static function main():Void {
		var stage:Stage = null;
		new OpenFLSmoke();
	}
}
