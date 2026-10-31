import haxe.io.Path;
import lime.utils.AssetLibrary;
import lime.utils.AssetType;
import sys.FileSystem;

/** Serves a folder as a Lime asset library, with ids like those of `<assets path="Assets" rename="assets" />`. **/
class FolderLibrary extends AssetLibrary {
	public function new() {
		super();
	}

	/** Adds the files under `dir`, with ids starting at `prefix`. **/
	public function add(dir:String, prefix:String):Void {
		scan(dir, prefix);
	}

	function scan(dir:String, id:String):Void {
		for (name in FileSystem.readDirectory(dir)) {
			var path = Path.join([dir, name]);
			var assetId = id == "" ? name : id + "/" + name;
			if (FileSystem.isDirectory(path)) {
				scan(path, assetId);
			} else {
				paths.set(assetId, path);
				types.set(assetId, typeOf(name));
			}
		}
	}

	static function typeOf(name:String):AssetType {
		return switch (Path.extension(name).toLowerCase()) {
			case "png", "jpg", "jpeg", "gif", "bmp": IMAGE;
			case "ttf", "otf", "woff", "woff2": FONT;
			case "wav": SOUND;
			case "ogg", "mp3": MUSIC;
			case "txt", "json", "xml", "csv", "html", "css": TEXT;
			default: BINARY;
		}
	}
}
