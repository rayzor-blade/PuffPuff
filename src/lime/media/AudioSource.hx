package lime.media;

import lime.app.Event;
import lime.math.Vector4;
import media.MediaPlayer;
import media.PlaybackState;

/**
 * Lime AudioSource backed by `hlavi` (`media.MediaPlayer`).
 */
class AudioSource {
	public var onComplete = new Event<Void->Void>();

	public var buffer:AudioBuffer;
	public var currentTime(get, set):Int;
	public var gain(get, set):Float;
	public var length(get, set):Int;
	public var loops:Int;
	public var offset:Int;
	public var pitch(get, set):Float;
	public var position(get, set):Vector4;

	@:noCompletion private var __player:Null<MediaPlayer>;
	@:noCompletion private var __gain:Float = 1.0;
	@:noCompletion private var __pitch:Float = 1.0;
	@:noCompletion private var __position:Vector4;
	@:noCompletion private var __length:Null<Int>;
	@:noCompletion private var __playing:Bool = false;

	public function new(buffer:AudioBuffer = null, offset:Int = 0, length:Null<Int> = null, loops:Int = 0) {
		this.buffer = buffer;
		this.offset = offset;
		this.__length = length;
		this.loops = loops;
		this.__position = new Vector4();

		init();
	}

	public function init():Void {
		if (buffer != null && buffer.__srcPath != null && sys.FileSystem.exists(buffer.__srcPath)) {
			__player = MediaPlayer.open(buffer.__srcPath);
			__player.setVolume(__gain);
		}
	}

	public function play():Void {
		if (__player == null && buffer != null && buffer.__srcPath != null) {
			init();
		}
		if (__player != null) {
			if (offset > 0) {
				__player.seek(offset / 1000.0);
			}
			__player.play();
			__playing = true;
		}
	}

	public function pause():Void {
		if (__player != null) {
			__player.pause();
			__playing = false;
		}
	}

	public function stop():Void {
		if (__player != null) {
			__player.pause();
			__player.seek(0.0);
			__playing = false;
		}
	}

	public function dispose():Void {
		if (__player != null) {
			__player.close();
			__player = null;
		}
		__playing = false;
	}

	private function get_currentTime():Int {
		if (__player != null) {
			return Std.int(__player.position() * 1000.0) - offset;
		}
		return 0;
	}

	private function set_currentTime(value:Int):Int {
		if (__player != null) {
			__player.seek((value + offset) / 1000.0);
		}
		return value;
	}

	private function get_gain():Float return __gain;
	private function set_gain(value:Float):Float {
		__gain = value;
		if (__player != null) {
			__player.setVolume(value);
		}
		return value;
	}

	private function get_length():Int {
		if (__length != null) return __length;
		if (__player != null) {
			return Std.int(__player.duration() * 1000.0) - offset;
		}
		return 0;
	}

	private function set_length(value:Int):Int {
		return __length = value;
	}

	private function get_pitch():Float return __pitch;
	private function set_pitch(value:Float):Float return __pitch = value;

	private function get_position():Vector4 return __position;
	private function set_position(value:Vector4):Vector4 {
		if (value != null) __position.copyFrom(value);
		return __position;
	}
}
