package hscript;

class CustomClassHandler implements IHScriptCustomConstructor {
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
			interp.execute(expr);
		}

		var cl = extend == null ? TemplateClass : Type.resolveClass('${name}_HSX');
		var _class = Type.createInstance(cl, args);
		//interp.variables.set("this", interp.variables);

		_class.interp = interp;

		var newFunc = interp.variables.get("new");
		if(newFunc != null) {
			Reflect.callMethod(null, newFunc, args);
		}

		for(variable => value in interp.variables) {
			if(variable == "this") continue;
			trace(variable, value, Reflect.isFunction(value));
		}

		return _class;
	}

	public function toString():String {
		return name;
	}
}

class TemplateClass implements IHScriptCustomBehaviour {
	public var interp:Interp;

	public function hset(name:String, val:Dynamic):Dynamic {
		if(Reflect.hasField(this, name)) {
			Reflect.setProperty(this, name, val);
			return Reflect.getProperty(this, name); // Incase it overwrites the return value
		}
		if(this.interp.variables.exists("set_" + name)) {
			return this.interp.variables.get("set_" + name)(val); // TODO: Prevent recursion from setting it in the function
		}
		this.interp.variables.set(name, val);
		return val;
	}
    public function hget(name:String):Dynamic {
		if(Reflect.hasField(this, name)) {
			return Reflect.getProperty(this, name);
		}
		return this.interp.variables.get(name);
	}
}