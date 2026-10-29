// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;

class AssetCache {
	public var audio:Map<String, AudioBuffer>;
	public var enabled:Bool = true;
	public var font:Map<String, Font>;
	public var image:Map<String, Image>;
	public var version:Int = 1;

	public function new() {
		audio = new Map<String, AudioBuffer>();
		font = new Map<String, Font>();
		image = new Map<String, Image>();
	}

	public function clear(prefix:String = null):Void {
		if (prefix == null) {
			audio.clear();
			font.clear();
			image.clear();
		} else {
			for (k in audio.keys()) if (StringTools.startsWith(k, prefix)) audio.remove(k);
			for (k in font.keys()) if (StringTools.startsWith(k, prefix)) font.remove(k);
			for (k in image.keys()) if (StringTools.startsWith(k, prefix)) image.remove(k);
		}
	}
}
