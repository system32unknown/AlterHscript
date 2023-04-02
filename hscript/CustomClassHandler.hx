package hscript;

class CustomClassHandler implements IHScriptCustomConstructor {
	public static var staticHandler = new StaticHandler();

	public var ogInterp:Interp;
	public var name:String;
	public var fields:Array<Expr>;
	public var extend:String;
	public var interfaces:Array<String>;

	public function new(ogInterp:Interp, name:String, fields:Array<Expr>, ?extend:String, ?interfaces:Array<String>) {
		this.ogInterp = ogInterp;
		this.name = name;
		this.fields = fields;
		this.extend = extend;
		this.interfaces = interfaces;
	}

	public function hnew(args:Array<Dynamic>):Dynamic {
		var interp = new Interp();

		interp.errorHandler = ogInterp.errorHandler;

		for(expr in fields) {
			@:privateAccess
			interp.exprReturn(expr);
		}

		var cl = extend == null ? TemplateClass : Type.resolveClass('${extend}_HSX');
		var _class = Type.createInstance(cl, args);

		interp.variables.set("super", staticHandler);

		_class.__interp = interp;
		interp.scriptObject = _class;

		var newFunc = interp.variables.get("new");
		if(newFunc != null) {
			Reflect.callMethod(null, newFunc, args);
		}

		for(variable => value in interp.variables) {
			if(variable == "this") continue;
		}

		return _class;
	}

	public function toString():String {
		return name;
	}
}

class TemplateClass implements IHScriptCustomBehaviour {
	public var __interp:Interp;

	public function hset(name:String, val:Dynamic):Dynamic {
		if(Reflect.hasField(this, name)) {
			Reflect.setProperty(this, name, val);
			return Reflect.getProperty(this, name); // Incase it overwrites the return value
		}
		if(this.__interp.variables.exists("set_" + name)) {
			return this.__interp.variables.get("set_" + name)(val); // TODO: Prevent recursion from setting it in the function
		}
		this.__interp.variables.set(name, val);
		return val;
	}
    public function hget(name:String):Dynamic {
		if(Reflect.hasField(this, name)) {
			return Reflect.getProperty(this, name);
		}
		return this.__interp.variables.get(name);
	}
}

class StaticHandler {
	public function new() {}
}