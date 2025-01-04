package hscript;

interface IHScriptCustomClassBehaviour {
	public var __interp:Interp;
	public var __custom__variables:Map<String, Dynamic>;
	public var __allowSetGet:Bool;
	public var __real_fields:Array<String>;
	public var __class__fields:Array<String>;

	public function hset(name:String, val:Dynamic):Dynamic;
	public function hget(name:String):Dynamic;

	public function __callGetter(name:String):Dynamic;

	public function __callSetter(name:String, val:Dynamic):Dynamic;
}