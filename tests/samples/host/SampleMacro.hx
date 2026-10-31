import haxe.macro.Context;
import haxe.macro.Expr;

class SampleMacro {
	/** `new Main()` for the class named by the `sample_main` define. **/
	public static macro function create():Expr {
		var parts = Context.definedValue("sample_main").split(".");
		var name = parts.pop();
		return {expr: ENew({pack: parts, name: name}, []), pos: Context.currentPos()};
	}
}
