package hscript.utils;

@:structInit
class UsingEntry  {
	public var call:Dynamic->String->Array<Dynamic>->Dynamic;
	public var fields:Array<String>;

	public function hasField(name:String) {
		return fields.contains(name);
	}
}

/**
 * Special class that handles static extension function calls. 
 * 
 * A static extension allows pseudo-extending 
 * existing types without modifying their source.
 * In Haxe this is achieved by declaring a static method with a first argument 
 * of the extending type and then bringing the defining class into context through `using`.
 * 
 * Example:
 * ```haxe
 * class IntExtender {
 * 	static public function triple(i:Int) {
 * 	 	return i * 3;
 * 	}
 * }
 * 
 * using IntExtender;
 * 
 * trace(12.triple()); // 36
 * ```
 * 
 * @see https://haxe.org/manual/lf-static-extension.html
 */
class UsingHandler { // The ACTUAL UsingHandler.hx >:3
	@:allow(hscript.CustomClass)
	@:allow(hscript.CustomClassHandler)
	public var usingEntries(default, null):Map<String, UsingEntry> = [];

	public function new() {}

	public function registerEntry(name:String, entry:Dynamic->String->Array<Dynamic>->Dynamic, fields:Array<String>) {
		usingEntries.set(name, {call: entry, fields: fields});
	}

	public function entryExists(name:String):Bool {
		return usingEntries.exists(name);
	}
}
