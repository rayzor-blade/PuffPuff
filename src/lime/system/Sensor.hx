// Lime API compatibility layer — adapted from OpenFL Lime (https://github.com/openfl/lime, MIT License)
package lime.system;

import lime.app.Event;

class Sensor {
	public static var sensors = new Map<Int, Sensor>();
	public static var onConnect = new Event<Sensor->Void>();

	public var id:Int;
	public var onUpdate = new Event<Float->Float->Float->Void>();
	public var type:SensorType;

	public function new(type:SensorType, id:Int) {
		this.type = type;
		this.id = id;
	}

	public static function getSensors(type:SensorType = null):Array<Sensor> {
		var result:Array<Sensor> = [];
		for (s in sensors) {
			if (type == null || s.type == type) result.push(s);
		}
		return result;
	}
}
