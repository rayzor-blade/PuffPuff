// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.net;

class URIParser {
	public var source:String;
	public var protocol:String;
	public var authority:String;
	public var userInfo:String;
	public var user:String;
	public var password:String;
	public var host:String;
	public var port:String;
	public var relative:String;
	public var path:String;
	public var directory:String;
	public var file:String;
	public var query:String;
	public var anchor:String;
	public var queryArray:Array<Dynamic>;

	private static var URI_REGEX = ~/^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/;

	public function new(uri:String) {
		source = uri;
		queryArray = [];
		if (uri != null && URI_REGEX.match(uri)) {
			protocol = URI_REGEX.matched(1) != null ? URI_REGEX.matched(1) : "";
			authority = URI_REGEX.matched(2) != null ? URI_REGEX.matched(2) : "";
			userInfo = URI_REGEX.matched(3) != null ? URI_REGEX.matched(3) : "";
			user = URI_REGEX.matched(4) != null ? URI_REGEX.matched(4) : "";
			password = URI_REGEX.matched(5) != null ? URI_REGEX.matched(5) : "";
			host = URI_REGEX.matched(6) != null ? URI_REGEX.matched(6) : "";
			port = URI_REGEX.matched(7) != null ? URI_REGEX.matched(7) : "";
			relative = URI_REGEX.matched(8) != null ? URI_REGEX.matched(8) : "";
			path = URI_REGEX.matched(9) != null ? URI_REGEX.matched(9) : "";
			directory = URI_REGEX.matched(10) != null ? URI_REGEX.matched(10) : "";
			file = URI_REGEX.matched(11) != null ? URI_REGEX.matched(11) : "";
			query = URI_REGEX.matched(12) != null ? URI_REGEX.matched(12) : "";
			anchor = URI_REGEX.matched(13) != null ? URI_REGEX.matched(13) : "";
		}
	}
}
