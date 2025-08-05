package alterhscript;

import haxe.ds.StringMap;
import hscript.*;
import alterhscript.ErrorSeverity;
import alterhscript.AlterConfig;
import haxe.CallStack;
import haxe.PosInfos;

using alterhscript.utils.Ansi;

@:structInit
class AlterCall {
	/**
	 * an HScript Function Name.
	**/
	public var funName:String;

	/**
	 * an HScript Function's signature.
	**/
	public var signature:Dynamic;

	/**
	 * an HScript Method's return value.
	**/
	public var returnValue:Dynamic;
}

/**
 * This basic object helps with the creation of scripts,
 * along with having neat helper functions to initialize and stop scripts
 *
 * It is highly recommended that you override this class to add custom defualt variables and such.
 * Hscript-Iris but I modified it.
**/
class AlterHscript {
	/**
	 * Map with stored instances of scripts.
	**/
	public static var instances:StringMap<AlterHscript> = new StringMap<AlterHscript>();

	static function getDefaultPos(name:String = "hscript-alter"):PosInfos {
		return {
			fileName: name,
			lineNumber: -1,
			className: "UnknownClass",
			methodName: "unknownFunction",
			customParams: null
		}
	}

	/**
	 * Custom warning function for script wrappers.
	 *
	 * Overriding is recommended if you're doing custom error handling.
	**/
	public dynamic static function logLevel(level:ErrorSeverity, x, ?pos:PosInfos):Void {
		if (pos == null) pos = getDefaultPos();

		var out:String = Std.string(x);
		if (pos != null && pos.customParams != null)
			for (i in pos.customParams) out += "," + i;

		var prefix:String = ErrorSeverityTools.getPrefix(level);
		if (prefix != "" && prefix != null) prefix = '$prefix:';
		var posPrefix:String = '[$prefix${pos.fileName}]';
		if (pos.lineNumber != -1) posPrefix = '[$prefix${pos.fileName}:${pos.lineNumber}]';

		if (prefix != "" && prefix != null) {
			posPrefix = posPrefix.fg(ErrorSeverityTools.getColor(level)).reset();
			if (level == FATAL) posPrefix = posPrefix.attr(INTENSITY_BOLD);
		}
		#if sys
		Sys.println((posPrefix + ": " + out).stripColor());
		#else
		// Since non-sys targets lack printLn, a simple trace should work
		trace((posPrefix + ": " + out).stripColor());
		#end
	}

	/**
	 * Custom print function for script wrappers.
	**/
	public dynamic static function print(x, ?pos:PosInfos): Void {
		logLevel(NONE, x, pos);
	}

	/**
	 * Custom error function for script wrappers.
	**/
	public dynamic static function error(x, ?pos:PosInfos):Void {
		logLevel(ERROR, x, pos);
	}

	/**
	 * Custom warning function for script wrappers.
	 *
	 * Overriding is recommended if you're doing custom error handling.
	**/
	public dynamic static function warn(x, ?pos:PosInfos):Void {
		logLevel(WARN, x, pos);
	}

	/**
	 * Custom fatal error function for script wrappers.
	**/
	public dynamic static function fatal(x, ?pos:PosInfos):Void {
		logLevel(FATAL, x, pos);
	}

	/**
	 * Config file, set when creating a new `AlterHscript` instance.
	**/
	public var config:AlterConfig = null;

	/**
	 * Current script name, from `config.name`.
	**/
	public var name(get, never):String;
	inline function get_name():String return config.name;

	/**
	 * The code passed in the `new` function for this script.
	 *
	 * contains a full haxe script instance
	**/
	var scriptCode:String = "";

	/**
	 * Current initialized script interpreter.
	**/
	public var interp:Interp;

	/**
	 * Current initialized script parser.
	**/
	public var parser:Parser;

	/**
	 * Current initialized script expression.
	**/
	var expr:Expr;

	/**
	 * Helper variable for the error string caused by a nulled interpreter.
	**/
	final interpErrStr:String = "Careful, the interpreter hasn't been initialized";

	/**
	 * Instantiates a new Script with the string value.
	 *
	 * ```haxe
	 * trace("Hello World!");
	 * ```
	 *
	 * will trace "Hello World!" to the standard output.
	 * @param scriptCode the script to be parsed, e.g:
	 */
	public function new(scriptCode:String, ?config:AutoAlterConfig):Void {
		if (config == null) config = new AlterConfig("AlterHscript", true, true, []);
		this.scriptCode = scriptCode;
		this.config = AlterConfig.from(config);
		this.config.name = fixScriptName(this.name);

		parser = new Parser();
		interp = new Interp();
		interp.showPosOnLog = false;

		interp.allowStaticVariables = interp.allowPublicVariables = true;
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
	
		if (this.config.autoPreset) preset(); // set variables to the interpreter.
		if (this.config.autoRun) execute(); // run the script.
	}

	static function fixScriptName(toFix:String):String {
		// make sure to never have an indentically named instance.
		var _name:String = toFix;
		var copyID:Int = 1;
		while (instances.exists(_name)) {
			_name = '${toFix}_${copyID}';
			copyID += 1;
		}
		return _name;
	}

	/**
	 * Executes this script and returns the interp's run result.
	**/
	public function execute():Dynamic {
		if (interp == null) throw "Attempt to run script failed, script is probably destroyed.";

		if (expr == null) expr = parse();
		instances.set(this.name, this);
		this.config.packageName = parser.packageName;
		return interp.execute(expr);
	}

	/**
	 * If you want to override the script, you should do parse(true);
	 *
	 * just parse(); otherwise, forcing may fix some behaviour depending on your implementation.
	**/
	public function parse(force:Bool = false):Expr {
		if (force || expr == null) return expr = parser.parseString(scriptCode);
		return expr;
	}

	/**
	 * Appends Default Classes/Enums for the Script to use.
	**/
	public function preset(): Void {
		set("Std", Std);
		set("StringTools", StringTools);
		set("Math", Math);
		#if hscriptPos
		// overriding trace for good measure.
		// if you're a game developer or a fnf modder (hi guys),
		// you might wanna use AlterHscript.print for your on-screen consoles and such.
		set("trace", Reflect.makeVarArgs(function(x:Array<Dynamic>) {
			var pos:PosInfos = this.interp != null ? this.interp.posInfos() : getDefaultPos(this.name);
			var v:Dynamic = x.shift();
			if (x.length > 0) pos.customParams = x;
			print(v, pos);
		}));
		#end
	}

	/**
	 * Returns a field from the script.
	 * @param field 	The field that needs to be looked for.
	 */
	public function get(field:String):Dynamic {
		#if ALTER_DEBUG
		if (interp == null) fatal("[AlterHscript:get()]: " + interpErrStr + ", when trying to get variable \"" + field + "\", returning false...");
		#end
		return interp != null ? interp.variables.get(field) : false;
	}

	/**
	 * Sets a new field to the script
	 * @param name          The name of your new field, scripts will be able to use the field with the name given.
	 * @param value         The value for your new field.
	 * @param allowOverride If set to true, when setting the new field, we will ignore any previously set fields of the same name.
	 */
	public function set(name:String, value:Dynamic, allowOverride:Bool = true):Void {
		if (interp == null || interp.variables == null) {
			#if ALTER_DEBUG
			fatal("[AlterHscript:set()]: " + interpErrStr + ", when trying to set variable \"" + name + "\" so variables cannot be set.");
			#end
			return;
		}
		if (allowOverride || !interp.variables.exists(name)) interp.setVar(name, value);
	}

	/**
	 * Calls a method on the script
	 * @param fun       The name of the method you wanna call.
	 * @param args      The arguments that the method needs.
	 */
	public function call(fun:String, ?args:Array<Dynamic>):AlterCall {
		if (interp == null) {
			#if ALTER_DEBUG
			trace("[AlterHscript:call()]: " + interpErrStr + ", so functions cannot be called.");
			#end
			return null;
		}
		args ??= [];

		var ny:Dynamic = interp.variables.get(fun);
		var isFunction:Bool = false;
		try {
			isFunction = ny != null && Reflect.isFunction(ny);
			if (!isFunction) throw 'Tried to call a non-function, for "$fun"';

			final ret:Dynamic = Reflect.callMethod(null, ny, args);
			return {funName: fun, signature: ny, returnValue: ret};
		}
		#if hscriptPos
		catch (e:Expr.Error) {error(Printer.errorToString(e, false), this.interp.posInfos());}
		#end
		catch (e:haxe.Exception) {
			var pos:PosInfos = isFunction ? this.interp.posInfos() : getDefaultPos(this.name);
			error(Std.string(e) #if ALTER_DEBUG + "\n" + CallStack.toString(CallStack.exceptionStack(true)) #end, pos);
		}
		return null;
	}

	/**
	 * Checks the existance of a field or method within your script.
	 * @param field 		The field to check if exists.
	 */
	public function exists(field:String):Bool {
		#if ALTER_DEBUG
		if (interp == null) trace("[AlterHscript:exists()]: " + interpErrStr + ", returning false...");
		#end
		return interp != null ? interp.variables.exists(field) : false;
	}

	/**
	 * Destroys the current instance of this script
	 * along with its parser, and also removes it from the `AlterHscript.instances` map.
	 *
	 * **WARNING**: this action CANNOT be undone.
	**/
	public function destroy():Void @:privateAccess {
		//First, Stopping Hscript-improved variables
		interp.__instanceFields = [];
		interp.binops.clear();
		interp.customClasses.clear();
		interp.declared = [];
		interp.importBlocklist = [];
		interp.locals.clear();
		interp.variables.clear();
		interp.resetVariables();

		if (instances.exists(this.name)) instances.remove(this.name);

		//Then, stops this script.
		interp = null;
		parser = null;
	}

	/**
	 * Destroys every single script found within the `AlterHscript.instances` map.
	 *
	 * **WARNING**: this action CANNOT be undone.
	**/
	public static function destroyAll():Void {
		for (key in instances.keys()) {
			var alter:AlterHscript = instances.get(key);
			if (alter.interp == null) continue;
			alter.destroy();
		}

		instances.clear();
		instances = new StringMap<AlterHscript>();
	}

	public function setParent(parent:Dynamic) {
		interp.scriptObject = parent;
	}
}