package hscript;

import hscript.Interp.DeclaredVar;
import hscript.utils.UnsafeReflect;
using StringTools;

// BIG TODO: revamp this
/**
 * Provides handlers for static custom class fields and instantiation.
 */
@:access(hscript.Property)
class CustomClassHandler implements IHScriptCustomConstructor implements IHScriptCustomAccessBehaviour{
	public static var staticHandler = new StaticHandler();

	public var __allowSetGet:Bool = true;

	public var ogInterp:Interp;
	public var name:String;
	public var fields:Array<Expr>;
	public var extend:Null<String>;
	public var interfaces:Array<String>;

	public var cl:Dynamic;

	private var staticInterp:Interp;
	private var staticFields:Array<String>;

	public function new(ogInterp:Interp, name:String, fields:Array<Expr>, ?extend:String, ?interfaces:Array<String>) {
		this.ogInterp = ogInterp;
		this.name = name;
		this.fields = fields;
		this.extend = extend;
		this.interfaces = interfaces;

		if(extend != null) {
			if(ogInterp.customClasses.exists(extend))
				this.cl = ogInterp.customClasses.get(extend);
			else 
				this.cl = Type.resolveClass('${extend}_HSX');

			if(cl == null)
				ogInterp.error(EInvalidClass(extend));
		}
		//this.cl = extend == null ? CustomTemplateClass : Type.resolveClass('${extend}_HSX');

		initStatic();
	}

	@:access(hscript.Interp)
	function initStatic() {
		staticInterp = new Interp();
		staticInterp.errorHandler = ogInterp.errorHandler;
		staticInterp.importFailedCallback = ogInterp.importFailedCallback;

		staticInterp.variables = ogInterp.variables;
		staticInterp.publicVariables = ogInterp.publicVariables;
		staticInterp.staticVariables = ogInterp.staticVariables;

		for(ex in fields) {
			var varOrFunction:Int = -1; // 0 - variable | 1 - function
			var staticField:Bool = false;
			var fieldName:String = "";
			switch (Tools.expr(ex)) {
				case EVar(n, _, _, _, isStatic, _, _, _, _, _, _):
					varOrFunction = 0;
					staticField = isStatic;
					fieldName = n;
				case EFunction(_, _, n, _, _, isStatic, _, _, _, _):
					varOrFunction = 1;
					staticField = isStatic;
					fieldName = n;
				default:
			}

			if(staticField && varOrFunction > -1) {
				staticInterp.exprReturn(ex);
				staticFields.push(fieldName);
				fields.remove(ex);
			}
		}
	}

	public function hnew(args:Array<Dynamic>):Dynamic {
		// TODO: clean this up, it sucks, i hate it
		// TODO: make static vars work correctly
		/*
		var interp = new Interp();

		interp.errorHandler = ogInterp.errorHandler;

		var _class:IHScriptCustomClassBehaviour = Type.createInstance(cl, args);

		//var __capturedLocals = ogInterp.duplicate(ogInterp.locals);
		//var capturedLocals:Map<String, DeclaredVar> = [];
		//for(k=>e in __capturedLocals)
		//	if (e != null && e.depth <= 0)
		//		capturedLocals.set(k, e);

		var disallowCopy = Type.getInstanceFields(cl);

		_class.__real_fields = disallowCopy;

		// todo: make it so you can use variables from the same scope as where the class was defined

		//for (key => value in capturedLocals) {
		//	if(!disallowCopy.contains(key)) {
		//		interp.locals.set(key, {r: value, depth: -1});
		//	}
		//}
		for (key => value in ogInterp.variables) {
			if(!disallowCopy.contains(key)) {
				interp.variables.set(key, value);
			}
		}
		for(key => value in ogInterp.customClasses) {
			if(!disallowCopy.contains(key)) {
				interp.customClasses.set(key, value);
			}
		}
		// todo: clone static vars, but make it so setting it only sets it on the class
		// todo: clone public vars

		//trace("Before: " + [for(key => value in interp.variables) key]);

		interp.variables.set("super", staticHandler);

		var comparisonMap:Map<String, Dynamic> = [];
		for(key => value in interp.variables) {
			comparisonMap.set(key, value);
		}

		_class.__custom__variables = interp.variables;

		//trace(fields);
		for(expr in fields) {
			@:privateAccess
			interp.exprReturn(expr);
		}

		//trace("After: " + [for(key => value in interp.variables) key]);

		// get only variables that were not set before
		var classVariables = [
			for(key => value in interp.variables)
				if(!comparisonMap.exists(key) || comparisonMap[key] != value)
					key => value
		];
		//for(variable => value in classVariables) {
		//	if(variable == "this" || variable == "super" || variable == "new") continue;
		//	@:privateAccess
		//	if(!interp.__instanceFields.contains(variable)) {
		//		interp.__instanceFields.push(variable);
		//	}
		//}

		_class.__class__fields = [for(key => value in classVariables) key];

		//trace(_class.__class__fields);
		//@:privateAccess
		//trace(interp.__instanceFields);

		_class.__interp = interp;
		_class.__allowSetGet = false;
		interp.scriptObject = _class;

		for(variable => value in interp.variables) {
			if(variable == "this" || variable == "super" || variable == "new") continue;

			if(variable.startsWith("set_") || variable.startsWith("get_")) {
				_class.__allowSetGet = true;
			}
		}

		var newFunc = interp.variables.get("new");
		if(newFunc != null) {
			var comparisonMap:Map<String, Dynamic> = [];
			for(key => value in interp.variables) {
				comparisonMap.set(key, value);
			}

			UnsafeReflect.callMethodUnsafe(null, newFunc, args);

			// get only variables that were not set before
			var classVariables = [
				for(key => value in interp.variables)
					if(!comparisonMap.exists(key) || comparisonMap[key] != value)
						key => value
			];
			for(variable => value in classVariables) {
				if(variable == "this" || variable == "super" || variable == "new") continue;
				@:privateAccess
				if(!interp.__instanceFields.contains(variable)) {
					interp.__instanceFields.push(variable);
				}
				if(!_class.__class__fields.contains(variable)) {
					_class.__class__fields.push(variable);
				}
			}
		}
		*/
		
		// I can't believe all these lines of code above got reduced to this sentence.
		var _class = new CustomClass(this, args);

		return _class;
	}

	function hasField(name:String) {
        return staticFields.contains(name);
    }

    function getField(name:String, allowProperty:Bool = true):Dynamic {
        var f = staticInterp.variables.get(name);
        if(f is Property && allowProperty) {
            var prop:Property = cast f;
            prop.__allowSetGet = this.__allowSetGet;
            var r = prop.callGetter(name);
            prop.__allowSetGet = null;
            return r;
        }
        return f;
    }

    function setField(name:String, val:Dynamic):Dynamic {
        var f = getField(name, false);
        if(f is Property) {
            var prop:Property = cast f;
            prop.__allowSetGet = this.__allowSetGet;
            var r = prop.callSetter(name, val);
            prop.__allowSetGet = null;
            return r;
        }
        staticInterp.variables.set(name, val);
        return val;
    }

	public function hget(name:String):Dynamic {
		if(hasField(name)) {
            return getField(name);
        }
		throw "field '"+ name+ "' does not exist in class '"+ this.name+ "'";
		return null;
	}

	public function hset(name:String, val:Dynamic):Dynamic {
		if(hasField(name))
			return setField(name, val);

		throw "field '"+ name+ "' does not exist in class '"+ this.name+ "'";
		return null;
	}

	// UNUSED
	public function __callGetter(name:String):Dynamic {
		return null;
	}

	public function __callSetter(name:String, val:Dynamic):Dynamic {
		return null;
	}

	public function toString():String {
		return name;
	}
}
/*
class CustomTemplateClass implements IHScriptCustomClassBehaviour {
	public var __interp:Interp;
	public var __allowSetGet:Bool = true;
	public var __custom__variables:Map<String, Dynamic>;
	public var __real_fields:Array<String>;
	public var __class__fields:Array<String>;

	public function hset(name:String, val:Dynamic):Dynamic {
		if(__allowSetGet && __custom__variables.exists("set_" + name))
			return __callSetter(name, val);
		if (__custom__variables.exists(name)) {
			__custom__variables.set(name, val);
			return val;
		}
		if(__real_fields.contains(name)) {
			UnsafeReflect.setProperty(this, name, val);
			return UnsafeReflect.field(this, name);
		}
		__custom__variables.set(name, val);
		return val;
	}
	public function hget(name:String):Dynamic {
		if(__allowSetGet && __custom__variables.exists("get_" + name))
			return __callGetter(name);
		if (__custom__variables.exists(name))
			return __custom__variables.get(name);

		return UnsafeReflect.getProperty(this, name);
	}

	public function __callGetter(name:String):Dynamic {
		__allowSetGet = false;
		var v = __custom__variables.get("get_" + name)();
		__allowSetGet = true;
		return v;
	}

	public function __callSetter(name:String, val:Dynamic):Dynamic {
		__allowSetGet = false;
		var v = __custom__variables.get("set_" + name)(val);
		__allowSetGet = true;
		return v;
	}
}
*/

/**
 * This is for backwards compatibility with old hscript-improved, since some scripts use it
**/
@:dox(hide)
@:keep
class TemplateClass implements IHScriptCustomBehaviour implements IHScriptCustomAccessBehaviour {
	public var __interp:Interp;
	public var __allowSetGet:Bool = true;

	public function hset(name:String, val:Dynamic):Dynamic {
		var variables = __interp.variables;
		if(__allowSetGet && variables.exists("set_" + name))
			return __callSetter(name, val);
		variables.set(name, val);
		return val;
	}
	public function hget(name:String):Dynamic {
		var variables = __interp.variables;
		if(__allowSetGet && variables.exists("get_" + name))
			return __callGetter(name);
		return variables.get(name);
	}

	public function __callGetter(name:String):Dynamic {
		__allowSetGet = false;
		var v = __interp.variables.get("get_" + name)();
		__allowSetGet = true;
		return v;
	}

	public function __callSetter(name:String, val:Dynamic):Dynamic {
		__allowSetGet = false;
		var v = __interp.variables.get("set_" + name)(val);
		__allowSetGet = true;
		return v;
	}
}

final class StaticHandler {
	public function new() {}
}