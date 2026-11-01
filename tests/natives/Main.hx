/**
 * Binds every native the package declares. HashLink checks each one's signature when it loads the bytecode, so
 * loading this program is the test. Nothing here needs a GPU.
 */
class Main {
	static function main():Void {
		Sys.println("all natives bound");
	}
}
