package hscript.utils;

typedef UsingCall = (o:Dynamic, f:String, args:Array<Dynamic>) -> Dynamic;

/**
 * Code based on Using system from "hscript-iris"
 * @see https://github.com/pisayesiwsi/hscript-iris/blob/master/crowplexus/iris/utils/UsingEntry.hx
 */
class UsingEntry {
	public var name:String;
	public var call:UsingCall;

	public function new(name: String, call:UsingCall) {
		this.name = name;
		this.call = call;
	}
}