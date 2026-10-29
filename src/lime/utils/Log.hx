// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

import haxe.PosInfos;

enum abstract LogLevel(Int) from Int to Int to UInt {
	public var NONE = 0;
	public var ERROR = 1;
	public var WARN = 2;
	public var INFO = 3;
	public var DEBUG = 4;
	public var VERBOSE = 5;

	@:op(A > B) static function gt(a:LogLevel, b:LogLevel):Bool;

	@:op(A >= B) static function gte(a:LogLevel, b:LogLevel):Bool;

	@:op(A < B) static function lt(a:LogLevel, b:LogLevel):Bool;

	@:op(A <= B) static function lte(a:LogLevel, b:LogLevel):Bool;
}

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
