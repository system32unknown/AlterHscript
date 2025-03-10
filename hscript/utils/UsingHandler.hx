package hscript.utils;

import hscript.utils.UsingEntry.UsingCall;
import StringTools;
import Lambda;

class UsingHandler {
    public static var usingEntries:Array<UsingEntry> = [
        new UsingEntry("StringTools", function(o: Dynamic, f: String, args: Array<Dynamic>): Dynamic {
			if (f == "isEof") // has @:noUsing
				return null;
			switch (Type.typeof(o)) {
				case TInt if (f == "hex"):
					return StringTools.hex(o, args[0]);
				case TClass(String):
					if (Reflect.hasField(StringTools, f)) {
						var field = Reflect.field(StringTools, f);
						if (Reflect.isFunction(field)) {
							return Reflect.callMethod(StringTools, field, [o].concat(args));
						}
					}
				default:
			}
			return null;
		}),
		new UsingEntry("Lambda", function(o: Dynamic, f: String, args: Array<Dynamic>): Dynamic {
			if (Tools.isIterable(o)) {
				// TODO: Check if the values are Iterable<T>
				if (Reflect.hasField(Lambda, f)) {
					var field = Reflect.field(Lambda, f);
					if (Reflect.isFunction(field)) {
						return Reflect.callMethod(Lambda, field, [o].concat(args));
					}
				}
			}
			return null;
		}),
    ];

    public static function registerUsingGlobal(name: String, call:UsingCall):UsingEntry {
		var entry = new UsingEntry(name, call);
		usingEntries.push(entry);
		return entry;
	}
}