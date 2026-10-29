package lime.app;

interface IModule {
	public function _onRegister(application:Application):Void;
	public function _onUnregister(application:Application):Void;
}

class Module implements IModule {
	public var onExit(default, null):Event<Int->Void>;

	public function new() {
		onExit = new Event<Int->Void>();
	}

	public function _onRegister(application:Application):Void {}

	public function _onUnregister(application:Application):Void {}
}
