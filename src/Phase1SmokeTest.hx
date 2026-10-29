package;

import lime.app.Application;
import lime.app.Event;
import lime.app.Future;
import lime.app.Promise;
import lime.graphics.Image;
import lime.graphics.RenderContext;
import lime.math.Matrix4;
import lime.math.Vector4;
import lime.media.AudioBuffer;
import lime.media.AudioSource;
import lime.system.System;
import lime.text.Font;
import lime.ui.Gamepad;
import lime.ui.GamepadAxis;
import lime.ui.GamepadButton;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.MouseButton;
import lime.ui.Touch;
import lime.utils.Assets;
import lime.utils.Float32Array;
import lime.utils.Int16Array;
import lime.utils.UInt8Array;
import puffpuff.snapshot.Png;

class Phase1SmokeTest extends Application {
	private var hue:Float = 0.0;

	public static function main():Void {
		// 1. Test Event<T>
		var ev = new Event<Int->String->Void>();
		var received:String = null;
		ev.add((code, msg) -> {
			received = '$code:$msg';
		});
		ev.dispatch(200, "OK");
		if (received != "200:OK") throw 'Event test failed: $received';

		// 2. Test Promise<T> and Future<T>
		var promise = new Promise<Int>();
		var futureVal = 0;
		promise.future.onComplete(v -> futureVal = v);
		promise.complete(42);
		if (futureVal != 42) throw 'Promise/Future test failed: $futureVal';

		// 3. Test Float32Array, UInt8Array, Vector4, Matrix4 (ash-simd)
		var f32 = new Float32Array([1.0, 2.0, 3.0, 4.0]);
		if (f32[2] != 3.0) throw 'Float32Array test failed';
		var u8 = new UInt8Array([10, 20, 255]);
		if (u8[2] != 255) throw 'UInt8Array test failed';

		var v1 = new Vector4(1, 2, 3, 1);
		var v2 = new Vector4(4, 5, 6, 1);
		var vSum = v1.add(v2);
		if (vSum.x != 5 || vSum.y != 7 || vSum.z != 9) throw 'Vector4 SIMD add failed';

		var m1 = new Matrix4();
		var m2 = new Matrix4();
		m1.createOrtho(0, 800, 600, 0, -1, 1);
		m1.append(m2);

		// 4. Test Image buffer creation and AudioBuffer/AudioSource (hlavi)
		var img = new Image(null, 0, 0, 16, 16, 0xFF336699);
		if (img.width != 16 || img.data.length != 16 * 16 * 4) throw 'Image test failed';

		var audioBuf = new AudioBuffer();
		var audioSrc = new AudioSource(audioBuf);
		audioSrc.gain = 0.75;
		if (audioSrc.gain != 0.75) throw 'AudioSource gain test failed';

		// 5. Test Int16Array, PNG encode/decode roundtrip, Assets, Gamepad, Touch, Font
		var i16 = new Int16Array([-32000, 0, 32000]);
		if (i16[0] != -32000 || i16[2] != 32000) throw 'Int16Array signed test failed: ${i16[0]}, ${i16[2]}';

		var encodedPng = Png.encode(img.width, img.height, img.data);
		var decodedImg = Image.fromBytes(encodedPng);
		if (decodedImg == null || decodedImg.width != 16 || decodedImg.height != 16) throw 'Image PNG roundtrip failed';
		if (decodedImg.data.get(0) != 0x33 || decodedImg.data.get(1) != 0x66 || decodedImg.data.get(2) != 0x99) {
			throw 'Image PNG pixel mismatch';
		}

		Gamepad.__poll();
		if (GamepadButton.toString(GamepadButton.A) != "A") throw 'GamepadButton test failed';
		if (GamepadAxis.toString(GamepadAxis.LEFT_X) != "LEFT_X") throw 'GamepadAxis test failed';
		var touch = new Touch(0.5, 0.5, 1, 0, 0, 1.0, 0);
		if (touch.id != 1) throw 'Touch test failed';
		var font = new Font("Arimo");
		if (font.name != "Arimo" || font.ascender <= 0 || font.descender >= 0) throw 'Font metrics test failed';
		var measured = font.measureText("PuffPuff GPU Text", 24.0);
		if (measured.width <= 0 || measured.ascent <= 0) throw 'Font measureText test failed';
		var outline = font.getOutline("PuffPuff", 24.0);
		if (outline == null || outline.commands.length == 0) throw 'Font getOutline test failed';

		var ttfFixture = "../blinc_abi/fixtures/font-face/regular.ttf";
		if (sys.FileSystem.exists(ttfFixture)) {
			var rawTtf = Font.fromFile(ttfFixture, true);
			if (rawTtf.name != "Blinc Embedded Fixture" || !rawTtf.pixelMode || rawTtf.unitsPerEM <= 0) {
				throw 'Raw TTF table parsing failed: name=${rawTtf.name}, upem=${rawTtf.unitsPerEM}';
			}
			var ttfMeasure = rawTtf.measureText("MIM", 20.0);
			if (ttfMeasure.width <= 0) throw 'Raw TTF shaping failed';
		}

		// 6. Test Window + WgpuContext + Application render loop (3 frames)
		var app = new Phase1SmokeTest();
		app.create({
			windows: [{
				title: "PuffPuff Phase 1 Smoke Test",
				width: 640,
				height: 360,
				vsync: true,
				background: 0xFF1A2B3C
			}]
		});
		app.exec(3);

		Sys.println('Phase 1 unit + window/wgpu swapchain checks passed (t=${System.getTimer()}ms).');
	}

	public override function render(context:RenderContext):Void {
		hue = (hue + 0.01) % 1.0;
		context.wgpu.clear(0.1, 0.2 + hue * 0.5, 0.4, 1.0);
	}
}
