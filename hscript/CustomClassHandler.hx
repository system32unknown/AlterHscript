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
        return name; // TODO!!! only for testing here
    }

    public function toString():String {
        return name;
    }
}