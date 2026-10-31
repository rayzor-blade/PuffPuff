package puffpuff.gpu;

import haxe.io.Bytes;

/**
 * An HXSL shader class as a draw program: its WGSL, vertex input locations, textures and uniform block. Parameters are
 * written to the block by name. Each program has its own block, and the layout is shared by every program of a class.
 * Reads the constants hlwgpu's build macro adds to the class.
 */
class HxslProgram {
	static var layouts:Map<String, Layout> = new Map();

	public final layout:Layout;

	/** Uniform block contents. **/
	public final params:Bytes;

	public static function of(cls:Class<Dynamic>):HxslProgram {
		var at = cls;
		while (at != null) {
			var wgsl:Null<String> = Reflect.field(at, "WGSL");
			if (wgsl != null) {
				var name = Type.getClassName(at);
				var layout = layouts.get(name);
				if (layout == null) {
					layout = read(at, name, wgsl);
					layouts.set(name, layout);
				}
				return new HxslProgram(layout);
			}
			at = cast Type.getSuperClass(at);
		}
		throw 'PuffPuff: ${Type.getClassName(cls)} is not an HXSL shader';
	}

	static function read(cls:Class<Dynamic>, name:String, wgsl:String):Layout {
		var offsets = new Map<String, Int>();
		var inputs = new Map<String, Int>();
		var textures:Array<{name:String, binding:Int}> = [];
		for (field in Type.getClassFields(cls)) {
			var value:Dynamic = Reflect.field(cls, field);
			if (!Std.isOfType(value, Int)) continue;
			if (StringTools.startsWith(field, "PARAMS_")) {
				var member = field.substr(7);
				if (member != "SIZE" && member != "GROUP" && member != "BINDING") offsets.set(member, value);
			} else if (StringTools.startsWith(field, "INPUT_")) {
				inputs.set(field.substr(6), value);
			} else if (StringTools.startsWith(field, "TEXTURE_") && !StringTools.endsWith(field, "_GROUP")) {
				textures.push({name: field.substr(8), binding: value});
			}
		}
		textures.sort((a, b) -> a.binding - b.binding);
		var size:Null<Int> = Reflect.field(cls, "PARAMS_SIZE");
		return {
			key: "program:" + name,
			wgsl: wgsl,
			paramsSize: size == null ? 0 : size,
			offsets: offsets,
			inputs: inputs,
			textures: textures
		};
	}

	function new(layout:Layout) {
		this.layout = layout;
		params = Bytes.alloc(layout.paramsSize);
		params.fill(0, layout.paramsSize, 0);
	}

	/** Vertex attribute location of input `name`, or -1. **/
	public function inputLocation(name:String):Int {
		var at = layout.inputs.get(name);
		return at == null ? -1 : at;
	}

	/** Texture slot of `name` for `setTextureAt`, or -1. Slots follow the order the shader declares its textures. **/
	public function textureSlot(name:String):Int {
		for (i in 0...layout.textures.length) if (layout.textures[i].name == name) return i;
		return -1;
	}

	/** Writes `values` to parameter `name`. False if the shader doesn't read it. **/
	public function setFloats(name:String, values:Array<Float>):Bool {
		var at = layout.offsets.get(name);
		if (at == null) return false;
		var room = Std.int((layout.paramsSize - at) / 4);
		for (i in 0...(values.length < room ? values.length : room)) params.setFloat(at + i * 4, values[i]);
		return true;
	}

	/** Writes `count` floats of `data` from `start` to parameter `name`. False if the shader doesn't read it. **/
	public function setRaw(name:String, data:lime.utils.Float32Array, start:Int = 0, count:Int = 16):Bool {
		var at = layout.offsets.get(name);
		if (at == null) return false;
		var room = Std.int((layout.paramsSize - at) / 4);
		var n = count < room ? count : room;
		params.blit(at, data.buffer, data.byteOffset + start * 4, n * 4);
		return true;
	}
}

typedef Layout = {
	key:String,
	wgsl:String,
	paramsSize:Int,
	offsets:Map<String, Int>,
	inputs:Map<String, Int>,
	textures:Array<{name:String, binding:Int}>
}
