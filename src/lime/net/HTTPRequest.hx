// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.net;

import haxe.io.Bytes;
import lime.app.Future;
import lime.app.Promise;

#if !macro
@:genericBuild(lime._internal.macros.HTTPRequestMacro.build())
#end
class HTTPRequest<T> extends AbstractHTTPRequest<T> {}

private class AbstractHTTPRequest<T> implements _IHTTPRequest {
	public var contentType:String;
	public var data:Bytes;
	public var enableResponseHeaders:Bool;
	public var followRedirects:Bool;
	public var formData:Map<String, Dynamic>;
	public var headers:Array<HTTPRequestHeader>;
	public var method:HTTPRequestMethod;
	public var responseData:T;
	public var responseHeaders:Array<HTTPRequestHeader>;
	public var responseStatus:Int;
	public var timeout:Int;
	public var uri:String;
	public var userAgent:String;
	public var verifyCertificates:Bool;
	public var withCredentials:Bool;
	public var manageCookies:Bool;

	@:noCompletion private var __backend:HTTPRequestBackend;

	public function new(uri:String = null) {
		this.uri = uri;
		contentType = "application/x-www-form-urlencoded";
		followRedirects = true;
		enableResponseHeaders = false;
		formData = new Map();
		headers = [];
		method = GET;
		timeout = 30000;
		withCredentials = false;
		manageCookies = true;
		verifyCertificates = true;
		__backend = new HTTPRequestBackend();
		__backend.init(this);
	}

	public function cancel():Void {
		__backend.cancel();
	}

	public function load(uri:String = null):Future<T> {
		return null;
	}
}

@:noCompletion class _HTTPRequest_Bytes<T> extends AbstractHTTPRequest<T> {
	public function new(uri:String = null) {
		super(uri);
	}

	@:noCompletion private function fromBytes(bytes:Bytes):T {
		return cast bytes;
	}

	public override function load(uri:String = null):Future<T> {
		if (uri != null) this.uri = uri;
		var promise = new Promise<T>();
		var future = __backend.loadData(this.uri);
		future.onProgress(promise.progress);
		future.onError(function(errorResponse:_HTTPRequestErrorResponse<T>) {
			responseData = errorResponse.responseData;
			promise.error(errorResponse.error);
		});
		future.onComplete(function(bytes) {
			responseData = fromBytes(bytes);
			promise.complete(responseData);
		});
		return promise.future;
	}
}

@:noCompletion class _HTTPRequest_String<T> extends AbstractHTTPRequest<T> {
	public function new(uri:String = null) {
		super(uri);
	}

	public override function load(uri:String = null):Future<T> {
		if (uri != null) this.uri = uri;
		var promise = new Promise<T>();
		var future = __backend.loadText(this.uri);
		future.onProgress(promise.progress);
		future.onError(function(errorResponse:_HTTPRequestErrorResponse<T>) {
			responseData = errorResponse.responseData;
			promise.error(errorResponse.error);
		});
		future.onComplete(function(text) {
			responseData = cast text;
			promise.complete(responseData);
		});
		return promise.future;
	}
}

@:noCompletion class _HTTPRequestErrorResponse<T> {
	public var error:Dynamic;
	public var responseData:T;

	public function new(error:Dynamic, responseData:T) {
		this.error = error;
		this.responseData = responseData;
	}
}

@:noCompletion interface _IHTTPRequest {
	public var contentType:String;
	public var data:Bytes;
	public var enableResponseHeaders:Bool;
	public var followRedirects:Bool;
	public var formData:Map<String, Dynamic>;
	public var headers:Array<HTTPRequestHeader>;
	public var method:HTTPRequestMethod;
	public var responseHeaders:Array<HTTPRequestHeader>;
	public var responseStatus:Int;
	public var timeout:Int;
	public var uri:String;
	public var userAgent:String;
	public var verifyCertificates:Bool;
	public var withCredentials:Bool;
	public var manageCookies:Bool;
	public function cancel():Void;
}

/**
	Loads a file path directly. Other URIs go through `haxe.Http` only with `-D puffpuff_http`, which makes
	every program that reaches this class need HashLink's `ssl` library at load time; without it they fail.
**/
private class HTTPRequestBackend {
	var parent:_IHTTPRequest;
	var cancelled = false;

	public function new() {}

	public function init(parent:_IHTTPRequest):Void {
		this.parent = parent;
	}

	public function cancel():Void {
		cancelled = true;
	}

	public function loadData(uri:String):Future<Bytes> {
		var promise = new Promise<Bytes>();
		cancelled = false;
		if (uri == null) {
			promise.error(new _HTTPRequestErrorResponse<Dynamic>("URI is null", null));
			return promise.future;
		}
		if (sys.FileSystem.exists(uri)) {
			try {
				var bytes = sys.io.File.getBytes(uri);
				parent.responseStatus = 200;
				promise.complete(bytes);
			} catch (e:Dynamic) {
				promise.error(new _HTTPRequestErrorResponse<Dynamic>(e, null));
			}
			return promise.future;
		}
		#if puffpuff_http
		try {
			var http = new haxe.Http(uri);
			for (h in parent.headers) http.setHeader(h.name, h.value);
			if (parent.userAgent != null) http.setHeader("User-Agent", parent.userAgent);
			if (parent.data != null) http.setPostBytes(parent.data);
			http.onStatus = status -> parent.responseStatus = status;
			http.onBytes = bytes -> if (!cancelled) promise.complete(bytes);
			http.onError = err -> if (!cancelled) promise.error(new _HTTPRequestErrorResponse<Dynamic>(err, null));
			http.request(parent.method == POST || parent.data != null);
		} catch (e:Dynamic) {
			promise.error(new _HTTPRequestErrorResponse<Dynamic>(e, null));
		}
		#else
		promise.error(new _HTTPRequestErrorResponse<Dynamic>('Cannot load $uri: network requests need -D puffpuff_http', null));
		#end
		return promise.future;
	}

	public function loadText(uri:String):Future<String> {
		var promise = new Promise<String>();
		var future = loadData(uri);
		future.onProgress(promise.progress);
		future.onError(promise.error);
		future.onComplete(bytes -> promise.complete(bytes.getString(0, bytes.length)));
		return promise.future;
	}
}
