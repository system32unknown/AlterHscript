package hscript;

import hscript.utils.UnsafeReflect;
import hscript.Interp;
import hscript.Expr.FieldPropertyAccess;

@:access(hscript.Interp)
@:structInit
class Property {
	public var r:Dynamic;
	public var getter:FieldPropertyAccess;
	public var setter:FieldPropertyAccess;

	var isVar:Bool;
	var interp:Interp;

	var __allowReadAccess:Bool = false;
	var __allowWriteAccess:Bool = false;

	public function callGetter(name:String) {
		switch (getter) {
			case AGet | ADynamic:
				var fName:String = 'get_$name';
				if (!__allowReadAccess && !interp.isBypassAccessor) {
					if (interp.varExists(fName)) {
						return callAccessor(fName);
					} else
						interp.error(ECustom('Method $fName required by property $name is missing'));
				} else {
					if ((setter == ADefault || setter == ANull) || isVar)
						return r;
					else
						interp.error(ECustom('Field $name cannot be accessed because it is not a real variable${interp.isBypassAccessor ? '. Add @:isVar to enable it' : ''}'));
				}
			case ANever:
				interp.error(ECustom('This expression cannot be accessed for reading'));
			default:
		}

		return r;
	}

	public function callSetter(name:String, val:Dynamic) {
		switch (setter) {
			case ASet | ADynamic:
				var fName:String = 'set_$name';
				if (!__allowWriteAccess && !interp.isBypassAccessor) {
					if (interp.varExists(fName))
						return callAccessor(fName, [val], true);
					else
						interp.error(ECustom('Method $fName required by property $name is missing'));
				} else {
					if ((getter == ADefault || getter == ANull) || isVar)
						return r = val;
					else
						interp.error(ECustom('Field $name cannot be accessed because it is not a real variable${interp.isBypassAccessor ? '. Add @:isVar to enable it' : ''}'));
				}
			case ANever:
				interp.error(ECustom('This expression cannot be accessed for writing'));
			default:
		}

		return r = val;
	}

	private function callAccessor(f:String, ?args:Array<Dynamic>, isWrite:Bool = false):Dynamic {
		var fn = interp.variables.get(f);
		var rt:Dynamic = null;
		if (fn != null && Reflect.isFunction(fn)) {
			if (isWrite) __allowWriteAccess = true;
			else __allowReadAccess = true;

			rt = UnsafeReflect.callMethodUnsafe(null, fn, args == null ? [] : args);

			if (isWrite) __allowWriteAccess = false;
			else __allowReadAccess = false;

			return rt;
		} else
			interp.error(ECustom('Method $f required by property ${f.substr(3)} is missing'));

		return rt;
	}
}
