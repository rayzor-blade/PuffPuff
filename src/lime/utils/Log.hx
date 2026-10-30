// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

import haxe.PosInfos;

class Log {
	public static var level:LogLevel = LogLevel.INFO;
	public static var throwErrors:Bool = true;

	public static function debug(message:Dynamic, ?info:PosInfos):Void {
		if (level >= LogLevel.DEBUG) {
			println('[DEBUG] $message', info);
		}
	}

	public static function error(message:Dynamic, ?info:PosInfos):Void {
		if (level >= LogLevel.ERROR) {
			var msg = '[ERROR] $message';
			if (throwErrors) {
				throw msg;
			} else {
				println(msg, info);
			}
		}
	}

	public static function info(message:Dynamic, ?info:PosInfos):Void {
		if (level >= LogLevel.INFO) {
			println('[INFO] $message', info);
		}
	}

	public static function println(message:Dynamic, ?info:PosInfos):Void {
		Sys.println(Std.string(message));
	}

	public static function verbose(message:Dynamic, ?info:PosInfos):Void {
		if (level >= LogLevel.VERBOSE) {
			println('[VERBOSE] $message', info);
		}
	}

	public static function warn(message:Dynamic, ?info:PosInfos):Void {
		if (level >= LogLevel.WARN) {
			println('[WARN] $message', info);
		}
	}
}
