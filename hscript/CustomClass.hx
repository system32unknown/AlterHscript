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
class CustomClass implements IHScriptCustomClassBehaviour{

    public var className(get, never):String;
    private function get_className():String
        return __class.name;

    public var __interp:Interp;
    public var __custom__variables:Map<String, Dynamic>; // TODO: remove this
    public var __real_fields:Array<String>;
    public var __class__fields:Array<String>; // Declared fields

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
        __interp.allowPublicVariables = __class.ogInterp.allowPublicVariables;
        __interp.publicVariables = __class.ogInterp.publicVariables;
        __interp.allowStaticVariables = __class.ogInterp.allowStaticVariables;
        __interp.staticVariables = __class.ogInterp.staticVariables;

        __interp.scriptObject = this;

        this.fields = __class.fields;
        for(f in fields) {
            switch(Tools.expr(f)) {
                case EVar(n):
                    __class__fields.push(n);
                case EFunction(_, _, n):
                    __class__fields.push(n);
                default:
            }
            @:privateAccess __interp.exprReturn(f);
        }

        if(hasField('new')) {
            buildConstructor();
            call('new', args);

            if(this.__superClass == null && __class.extend != null)
                __interp.error(ECustom("super() not called"));
        }
        else if(__class.extend != null) {
            buildSuperClass(args);
        }
            
    }

    function buildConstructor() {
        __constructor = Reflect.makeVarArgs(buildSuperClass);
    }

    function buildSuperClass(?args:Array<Dynamic>) {
        if(args == null)
            args = [];

        if(__class.cl == null) __interp.error(ECustom('Current class does not have a super'));

		if (__class.cl == CustomClassHandler) {
			__superClass = new CustomClass(__class.cl, args);
		} else {
			var disallowCopy = Type.getInstanceFields(__class.cl);
			__superClass = Type.createInstance(__class.cl, args);
			__superClass.__real_fields = disallowCopy;
            __superClass.__interp = this.__interp;
		}
    }

    function call(name:String, ?args:Array<Dynamic>):Dynamic {
        var fn = __interp.variables.get(name);
        if(fn != null && Reflect.isFunction(fn))
            return UnsafeReflect.callMethodUnsafe(null, fn, (args == null) ? [] : args);
        
        __interp.error(ECustom('$name is not a function'));
        return null;
    }

    function hasField(name:String) {
        return __interp.variables.exists(name);
    }

    public function hget(name:String):Dynamic {
        switch (name) {
            case 'superClass': return __superClass;
            case 'superConstructor': return __constructor;
        }
        return null;
    }

    public function __callGetter(name:String):Dynamic {
        return null;
    }

    public function hset(name:String, val:Dynamic):Dynamic {
        return null;
    }

    public function __callSetter(name:String, val:Dynamic):Dynamic {
        return null;
    }

    public function toString():String
        return className;
}