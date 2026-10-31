package puffpuff.gpu;

import haxe.io.Bytes;

/**
 * Wraps an HXSL class that extends `OffsetQuadShader`: its WGSL, and where its uniform block keeps the projection and the
 * premultiplied flag. Reads the constants hlwgpu's build macro adds to the class.
 */
class CustomQuadShader {
	static var known:Map<String, CustomQuadShader> = new Map();

	public final key:String;
	public final wgsl:String;
	public final paramsSize:Int;
	public final projectionAt:Int;
	public final premultipliedAt:Int;
	public final cls:Class<Dynamic>;

	function new(cls:Class<Dynamic>, wgsl:String) {
		this.cls = cls;
		key = "custom:" + Type.getClassName(cls);
		this.wgsl = wgsl;
		paramsSize = Reflect.field(cls, "PARAMS_SIZE");
		projectionAt = offsetOf("projection");
		premultipliedAt = offsetOf("premultiplied");
	}

	/** The shader of `cls` or the nearest class above it that has HXSL source, or `null`. **/
	public static function of(cls:Class<Dynamic>):Null<CustomQuadShader> {
		var at = cls;
		while (at != null) {
			var wgsl:Null<String> = Reflect.field(at, "WGSL");
			if (wgsl != null) {
				var name = Type.getClassName(at);
				var shader = known.get(name);
				if (shader == null) {
					shader = new CustomQuadShader(at, wgsl);
					known.set(name, shader);
				}
				return shader;
			}
			at = cast Type.getSuperClass(at);
		}
		return null;
	}

	/** Where parameter `name` sits in the uniform block, or -1 if the shader never reads it. **/
	public function offsetOf(name:String):Int {
		var at:Null<Int> = Reflect.field(cls, "PARAMS_" + name);
		return at == null ? -1 : at;
	}

	/** Uniform block with the parameters at their offsets. The batch adds the projection when it draws. **/
	public function block():Bytes {
		var bytes = Bytes.alloc(paramsSize);
		bytes.fill(0, paramsSize, 0);
		return bytes;
	}
}
