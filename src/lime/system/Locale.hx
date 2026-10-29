// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

abstract Locale(String) from String to String {
	public static var currentLocale(get, set):Locale;
	public static var systemLocale(get, never):Locale;

	private static var __currentLocale:Locale = "en-US";

	public var language(get, never):String;
	public var region(get, never):String;

	public inline function new(value:String) {
		this = value;
	}

	public function equals(locale:Locale):Bool {
		return language == locale.language && region == locale.region;
	}

	private function get_language():String {
		if (this == null) return null;
		var dash = this.indexOf("-");
		var under = this.indexOf("_");
		var sep = (dash >= 0 && (under < 0 || dash < under)) ? dash : under;
		return sep >= 0 ? this.substr(0, sep).toLowerCase() : this.toLowerCase();
	}

	private function get_region():String {
		if (this == null) return null;
		var dash = this.indexOf("-");
		var under = this.indexOf("_");
		var sep = (dash >= 0 && (under < 0 || dash < under)) ? dash : under;
		return sep >= 0 ? this.substr(sep + 1).toUpperCase() : null;
	}

	private static inline function get_currentLocale():Locale return __currentLocale;
	private static inline function set_currentLocale(v:Locale):Locale return __currentLocale = v;
	private static function get_systemLocale():Locale {
		var lang = Sys.getEnv("LANG");
		if (lang != null && lang.length >= 2) {
			var dot = lang.indexOf(".");
			return new Locale(dot > 0 ? lang.substr(0, dot) : lang);
		}
		return new Locale("en-US");
	}
}
