package puffpuff.media;

import haxe.io.Bytes;
import media.MediaPlayer;
import media.PlaybackState;
import media.VideoFrame;
import media.VideoFrameCopyToOptions;
import media.VideoPixelFormat;
import puffpuff.gpu.WgpuContext3D;
import puffpuff.gpu.WgpuContext3D.WgpuTexture;

/**
 * Hardware-accelerated video player and GPU texture uploader backed by `hlavi` (`media.MediaPlayer`) and `hlwgpu`.
 */
class VideoTexture {
	public var player(default, null):MediaPlayer;
	public var texture(default, null):Null<WgpuTexture>;
	public var width(default, null):Int = 0;
	public var height(default, null):Int = 0;
	public var context3D(default, null):WgpuContext3D;

	private var scratchBytes:Null<Bytes>;

	public function new(context3D:WgpuContext3D, path:String) {
		this.context3D = context3D;
		this.player = MediaPlayer.open(path);
	}

	public inline function play():Void player.play();
	public inline function pause():Void player.pause();
	public inline function seek(seconds:Float):Void player.seek(seconds);
	public inline function setVolume(vol:Float):Void player.setVolume(vol);
	public inline function state():PlaybackState return player.state();
	public inline function position():Float return player.position();
	public inline function duration():Float return player.duration();

	/**
	 * Polls `MediaPlayer` for a new decoded video frame, converts it to RGBA via `hlavi`,
	 * and uploads it into `this.texture` on the GPU. Returns `true` if a new frame was uploaded.
	 */
	public function updateTexture():Bool {
		if (!player.pollFrame()) return false;
		var frame:VideoFrame = player.takeFrame();
		var w = haxe.Int64.toInt(frame.displayWidth());
		var h = haxe.Int64.toInt(frame.displayHeight());
		if (w <= 0 || h <= 0) {
			frame.close();
			return false;
		}

		if (texture == null || width != w || height != h) {
			if (texture != null) texture.dispose();
			width = w;
			height = h;
			texture = context3D.createTexture(w, h);
		}

		var opts = new VideoFrameCopyToOptions();
		opts.format(VideoPixelFormat.RGBA);
		var needed = haxe.Int64.toInt(frame.allocationSize(opts));
		if (needed <= 0) needed = w * h * 4;

		if (scratchBytes == null || scratchBytes.length < needed) {
			scratchBytes = Bytes.alloc(needed);
		}

		frame.copyTo(scratchBytes, opts).await();
		frame.close();

		texture.uploadFromBytes(scratchBytes, w * 4);
		return true;
	}

	public function dispose():Void {
		if (texture != null) {
			texture.dispose();
			texture = null;
		}
		player.close();
	}
}

