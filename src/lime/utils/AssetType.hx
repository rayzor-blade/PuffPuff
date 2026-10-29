// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.utils;

enum abstract AssetType(String) from String to String {
	public var BINARY = "BINARY";
	public var FONT = "FONT";
	public var IMAGE = "IMAGE";
	public var MANIFEST = "MANIFEST";
	public var MUSIC = "MUSIC";
	public var SOUND = "SOUND";
	public var TEMPLATE = "TEMPLATE";
	public var TEXT = "TEXT";
}
