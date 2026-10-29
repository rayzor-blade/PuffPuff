// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

import haxe.Timer;
import lime.graphics.PixelFormat;

class System {
	private static var __startTime:Float = Timer.stamp();

	public static var allowScreenTimeout(get, set):Bool;
	public static var applicationDirectory(get, never):String;
	public static var applicationStorageDirectory(get, never):String;
	public static var desktopDirectory(get, never):String;
	public static var deviceModel(get, never):String;
	public static var deviceVendor(get, never):String;
	public static var disableCFFI:Bool;
	public static var documentsDirectory(get, never):String;
	public static var endianness(get, never):Endian;
	public static var fontsDirectory(get, never):String;
	public static var numDisplays(get, never):Int;
	public static var platformLabel(get, never):String;
	public static var platformName(get, never):String;
	public static var platformVersion(get, never):String;
	public static var userDirectory(get, never):String;

	public static inline function getTimer():Int {
		return Std.int((Timer.stamp() - __startTime) * 1000.0);
	}

	public static function exit(code:Int):Void {
		Sys.exit(code);
	}

	public static function getDisplay(id:Int):Display {
		var display = new Display();
		display.id = id;
		display.name = "Display " + id;
		display.currentMode = new DisplayMode(1920, 1080, 60, PixelFormat.RGBA32);
		return display;
	}

	public static function openFile(path:String):Void {
		if (path == null || path == "") return;
		switch (Sys.systemName()) {
			case "Mac": Sys.command("open", [path]);
			case "Linux": Sys.command("xdg-open", [path]);
			case "Windows": Sys.command("start", ["", path]);
			default:
		}
	}

	public static function openURL(url:String, target:String = "_blank"):Void {
		openFile(url);
	}

	private static function get_allowScreenTimeout():Bool return true;
	private static function set_allowScreenTimeout(v:Bool):Bool return v;
	private static function get_applicationDirectory():String return Sys.getCwd();
	private static function get_applicationStorageDirectory():String return Sys.getCwd();
	private static function get_desktopDirectory():String return Sys.getEnv("HOME") != null ? Sys.getEnv("HOME") + "/Desktop" : Sys.getCwd();
	private static function get_deviceModel():String return "";
	private static function get_deviceVendor():String return "";
	private static function get_documentsDirectory():String return Sys.getEnv("HOME") != null ? Sys.getEnv("HOME") + "/Documents" : Sys.getCwd();
	private static function get_endianness():Endian return Endian.LITTLE_ENDIAN;
	private static function get_fontsDirectory():String return "/System/Library/Fonts";
	private static function get_numDisplays():Int return 1;
	private static function get_platformLabel():String return Sys.systemName();
	private static function get_platformName():String return Sys.systemName();
	private static function get_platformVersion():String return "";
	private static function get_userDirectory():String return Sys.getEnv("HOME") != null ? Sys.getEnv("HOME") : Sys.getCwd();
}
