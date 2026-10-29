// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.net;

import haxe.io.Bytes;
import lime.app.Future;
import lime.app.Promise;

class HTTPRequest<T> {
	public var contentType:String;
	public var data:Bytes;
	public var enableResponseHeaders:Bool;
	public var followRedirects:Bool;
	public var formData:Map<String, Dynamic>;
	public var headers:Array<HTTPRequestHeader>;
	public var manageCookies:Bool;
	public var method:HTTPRequestMethod;
	public var responseData:T;
	public var responseHeaders:Array<HTTPRequestHeader>;
	public var responseStatus:Int;
	public var timeout:Int;
	public var uri:String;
	public var userAgent:String;
	public var withCredentials:Bool;

	public function new(uri:String = null) {
		this.uri = uri;
		contentType = "application/x-www-form-urlencoded";
		followRedirects = true;
		enableResponseHeaders = false;
		formData = new Map<String, Dynamic>();
		headers = [];
		manageCookies = true;
		method = GET;
		timeout = 30000;
		withCredentials = false;
	}

	public function cancel():Void {}

	public function load(uri:String = null):Future<T> {
		if (uri != null) this.uri = uri;
		var promise = new Promise<T>();
		if (this.uri == null) {
			promise.error("URI is null");
			return promise.future;
		}
		if (sys.FileSystem.exists(this.uri)) {
			try {
				var bytes = sys.io.File.getBytes(this.uri);
				responseStatus = 200;
				responseData = cast bytes;
				promise.complete(responseData);
			} catch (e:Dynamic) {
				promise.error(e);
			}
			return promise.future;
		}
		try {
			var http = new haxe.Http(this.uri);
			for (h in headers) http.setHeader(h.name, h.value);
			if (data != null) http.setPostBytes(data);
			http.onStatus = status -> responseStatus = status;
			http.onBytes = bytes -> {
				responseData = cast bytes;
				promise.complete(responseData);
			};
			http.onError = err -> promise.error(err);
			http.request(method == POST || data != null);
		} catch (e:Dynamic) {
			promise.error(e);
		}
		return promise.future;
	}
}
