package hscript;

import hscript.utils.UnsafeReflect;
import haxe.Constraints.Function;

using Lambda;

// TODO

/**
 * The Custom Class core.
 * 
 * Provides handlers for custom classes.
 * 
 * @author Jamextreme140
 */
@:access(hscript.CustomClassHandler)
@:access(hscript.Property)
class CustomClass implements IHScriptCustomClassBehaviour {
	public var className(get, never):String;

	private function get_className():String
		return __class.name;

	public var __interp:Interp;
	public var __real_fields:Array<String> = []; // UNUSED
	public var __class__fields:Array<String> = []; // Declared fields

	public var __allowSetGet:Bool = true;

	var __class:CustomClassHandler;
	var __superClass:IHScriptCustomClassBehaviour;
	var __constructor:Function;
	var fields:Array<Expr>;

	public function new(__class:CustomClassHandler, args:Array<Dynamic>) {
		this.__class = __class;

		__interp = new Interp();
		__interp.errorHandler = __class.staticInterp.errorHandler;
		__interp.importFailedCallback = __class.staticInterp.importFailedCallback;

		__interp.variables = __class.staticInterp.variables; // This will access to static fields
		__interp.publicVariables = __class.ogInterp.publicVariables;
		__interp.staticVariables = __class.ogInterp.staticVariables;

		this.fields = __class.fields;
		for (f in fields) {
			switch (Tools.expr(f)) {
				case EVar(n):
					__class__fields.push(n);
				case EFunction(_, _, n):
					__class__fields.push(n);
				default:
			}
			@:privateAccess __interp.exprReturn(f);
		}

		__interp.scriptObject = this;

		if (hasField('new')) {
			buildConstructor();
			call('new', args);

			if (this.__superClass == null && __class.extend != null)
				__interp.error(ECustom("super() not called"));
		} else if (__class.extend != null) {
			buildSuperClass(args);
		}
	}

	function buildConstructor() {
		__constructor = Reflect.makeVarArgs(buildSuperClass);
	}

	function buildSuperClass(?args:Array<Dynamic>) {
		if (args == null)
			args = [];

		if (__class.cl == null) {
			__interp.error(ECustom('Current class does not have a super'));
			return;
		}

		if (__class.cl == CustomClassHandler) {
			__superClass = new CustomClass(__class.cl, args);
			@:privateAccess
			__interp.__instanceFields.concat(__superClass.__class__fields);
		} else {
			var disallowCopy = Type.getInstanceFields(__class.cl);
			__superClass = Type.createInstance(__class.cl, args);
			__superClass.__real_fields = disallowCopy;
			__superClass.__class__fields = this.__class__fields;
			__superClass.__interp = this.__interp;
		}
	}

	public function call(name:String, ?args:Array<Dynamic>):Dynamic {
		var fn = __interp.variables.get(name);
		if (fn != null && Reflect.isFunction(fn))
			return UnsafeReflect.callMethodUnsafe(null, fn, (args == null) ? [] : args);
		else
			__interp.error(ECustom('$name is not a function'));
		return null;
	}

	function hasField(name:String) {
		// return __interp.variables.exists(name);
		return __class__fields.contains(name);
	}

	function getField(name:String, allowProperty:Bool = true):Dynamic {
		var f = __interp.variables.get(name);
		if (allowProperty && f is Property) {
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
		if (f is Property) {
			var prop:Property = cast f;
			prop.__allowSetGet = this.__allowSetGet;
			var r = prop.callSetter(name, val);
			prop.__allowSetGet = null;
			return r;
		}
		__interp.variables.set(name, val);
		return val;
	}

	function superHasField(name:String) {
		if (__superClass == null)
			return false;

		var realFieldExists = __superClass.__real_fields != null && __superClass.__real_fields.contains(name);
		var classFieldExists = __superClass.__class__fields != null && __superClass.__class__fields.contains(name);

		return realFieldExists || classFieldExists;
	}

	public function hget(name:String):Dynamic {
		switch (name) {
			case 'superClass': return __superClass;
			case 'superConstructor': return __constructor;
			default:
				if (hasField(name)) 
					return getField(name);

				if (__superClass != null) {
					if (superHasField(name)) {
						__superClass.__allowSetGet = this.__allowSetGet;
						return __superClass.hget(name);
					}
				}

				throw "field '"
					+ name
					+ "' does not exist in custom class '"
					+ this.className
					+ "'"
					+ (__superClass != null ? "' or super class '" + Type.getClassName(Type.getClass(this.__superClass)) + "'" : "");
		}
		return null;
	}

	public function hset(name:String, val:Dynamic):Dynamic {
		if (hasField(name)) {
			return setField(name, val);
		}

		if (__superClass != null) {
			if (superHasField(name)) {
				__superClass.__allowSetGet = this.__allowSetGet;
				return __superClass.hset(name, val);
			}
		}

		throw "field '"
			+ name
			+ "' does not exist in custom class '"
			+ this.className
			+ "'"
			+ (__superClass != null ? "' or super class '" + Type.getClassName(Type.getClass(this.__superClass)) + "'" : "");

		return null;
	}

	// UNUSED
	public function __callGetter(name:String):Dynamic {
		return null;
	}

	public function __callSetter(name:String, val:Dynamic):Dynamic {
		return null;
	}

	/**
	 * Returns the real superClass if the Custom Class
	 * extends another Custom Class, and so on until
	 * it reaches a real class, otherwise it will
	 * return the last fetched Custom Class
	 * @return Null<Dynamic>
	 */
	public function getSuperclass():IHScriptCustomClassBehaviour {
		var cls:Null<IHScriptCustomClassBehaviour> = this.__superClass;

		// Check if the superClass is another custom class,
		// so it will find for a real class, otherwise
		// returns the last super CustomClass parent.
		while (cls != null && cls is CustomClass) {
			var next = cast(cls, CustomClass).__superClass;
			if (next == null)
				break; // Return the Custom Class itself
			cls = next;
		}

		return cls;
	}

	public function toString():String
		return className;
}
