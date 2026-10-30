// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.app;

class Module implements IModule {
	public var onExit(default, null):Event<Int->Void>;

	public function new() {
		onExit = new Event<Int->Void>();
	}

	@:noCompletion private function __registerLimeModule(application:Application):Void {}

	@:noCompletion private function __unregisterLimeModule(application:Application):Void {}
}
