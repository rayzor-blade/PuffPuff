// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.net;

class HTTPRequestHeader {
	public var name:String;
	public var value:String;

	public function new(name:String, value:String = "") {
		this.name = name;
		this.value = value;
	}
}
