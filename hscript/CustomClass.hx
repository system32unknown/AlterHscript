package hscript;

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
class CustomClass /*implements IHScriptCustomClassBehaviour*/{

    public var className(get, never):String;
    private function get_className():String
        return __class.name;

    var interp:Interp;
    var __class:CustomClassHandler;
    var fields:Array<Expr>;
    
    public function new(__class:CustomClassHandler) {
        this.__class = __class;

        interp = new Interp();
        interp.errorHandler = __class.staticInterp.errorHandler;
        interp.scriptObject = this;

        fields = [];
        /*
        for(e in __class.fields) {
            switch (Tools.expr(e)) {
                case EVar(n, _, e, _, isStatic, _, isFinal, _, get, set, isVar):
                    if(!isStatic)
                        fields.push(e);
                case EFunction(args, e, name, ret, _, isStatic, _, _, isFinal, _):
                    if(!isStatic)
                        fields.push(e);
                default:
            }
        }
        */
        for(f in fields)
            @:privateAccess interp.exprReturn(f);

    }

    public function toString():String
        return className;
}