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

	/**
		The languages the user prefers, most preferred first, such as `en-US` or
		`fr`. It is read each time, as the user can change it while the
		application runs, and is empty where the platform doesn't say.
	**/
	public static var preferredLocales(get, never):Array<Locale>;

	private static function get_preferredLocales():Array<Locale>
	{
		var locales:Array<Locale> = [];

		#if flash
		#if air
		for (language in Capabilities.languages)
		{
			locales.push(language);
		}
		#else
		locales.push(Capabilities.language);
		#end
		#elseif (js && html5)
		var languages:Array<String> = untyped navigator.languages;
		if (languages == null) languages = [untyped navigator.language];

		for (language in languages)
		{
			if (language != null) locales.push(language);
		}
		#elseif sys
		// The first of these that is set, as `en_US.UTF-8` or a `:`-separated list of them.
		for (name in ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"])
		{
			var value = Sys.getEnv(name);
			if (value == null || value == "" || value == "C" || value == "POSIX") continue;

			for (entry in value.split(":"))
			{
				var language = entry.split(".")[0].split("@")[0].split("_").join("-");
				if (language != "" && language != "C" && language != "POSIX") locales.push(language);
			}
			break;
		}
		#end

		return locales;
	}


}
