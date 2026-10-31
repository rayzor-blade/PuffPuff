import lime.app.Application;
import puffpuff.gpu.WgpuContext3D;
import puffpuff.text.TextNative;

/** Compiles against the installed package, so its sources, extraParams.hxml and macros have to resolve. */
class Main {
	static function main():Void {
		var type:Class<Dynamic> = WgpuContext3D;
		trace(Type.getClassName(type), Application, TextNative.blinc_text_generation());
	}
}
