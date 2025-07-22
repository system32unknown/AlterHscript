package hscript;

import hscript.utils.UnsafeReflect;

// TODO: scripted enums
@:structInit
class HEnum implements IHScriptCustomBehaviour{
    private var enumValues(default, null) = {};

    public function setEnum(name:String, enumValue:Dynamic):Void {
        UnsafeReflect.setField(enumValues, name, enumValue);
    }

    public function getEnum(name:String):Null<Dynamic> {
        if(Reflect.hasField(enumValues, name)) return Reflect.field(enumValues, name);
        return null;
    }

    public function hget(name:String):Dynamic {
        return getEnum(name);
    }

    public function hset(name:String, val:Dynamic):Dynamic {
        return null;
    }
}
