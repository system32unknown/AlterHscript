/*
 * Copyright (C)2008-2017 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/*
 * YoshiCrafter Engine fixes:
 * - Added Error handler
 * - Added Imports
 * - Added @:bypassAccessor
 */
package hscript;

import haxe.PosInfos;
import hscript.Expr;
import haxe.Constraints.IMap;
import hscript.UnsafeReflect;

using StringTools;

enum abstract ScriptObjectType(UInt8) {
	var SClass;
	var SObject;
	var SStaticClass;
	var SCustomClass;
	var SBehaviourClass;
	var SNull;
}

@:structInit
class DeclaredVar {
	public var r:Dynamic;
	public var depth:Int;
}

@:structInit
class RedeclaredVar {
	public var n:String;
	public var old:DeclaredVar;
	public var depth:Int;
}

private enum Stop {
	SBreak;
	SContinue;
	SReturn;
}

class Interp {
	public var scriptObject(default, set):Dynamic;
	private var _hasScriptObject(default, null):Bool = false;
	private var _scriptObjectType(default, null):ScriptObjectType = SNull;
	public function set_scriptObject(v:Dynamic) {
		switch(Type.typeof(v)) {
			case TClass(c): // Class Access
				__instanceFields = Type.getInstanceFields(c);
				if(c is IHScriptCustomClassBehaviour) {
					_scriptObjectType = SCustomClass;
				} else if(c is IHScriptCustomBehaviour) {
					_scriptObjectType = SBehaviourClass;
				} else {
					_scriptObjectType = SClass;
				}
			case TObject: // Object Access or Static Class Access
				var cls = Type.getClass(v);
				switch(Type.typeof(cls)) {
					case TClass(c): // Static Class Access
						__instanceFields = Type.getInstanceFields(c);
						_scriptObjectType = SStaticClass;
					default: // Object Access
						__instanceFields = UnsafeReflect.fields(v);
						_scriptObjectType = SObject;
				}
			default: // Null or other
				__instanceFields = [];
				_scriptObjectType = SNull;
		}
		_hasScriptObject = v != null;
		return scriptObject = v;
	}
	public var errorHandler:Error->Void;
	public var importFailedCallback:Array<String>->Bool;
	public var onMetadata:String->Array<Expr>->Expr->Dynamic;
	#if haxe3
	public var customClasses:Map<String, Dynamic>;
	public var variables:Map<String, Dynamic>;
	public var publicVariables:Map<String, Dynamic>;
	public var staticVariables:Map<String, Dynamic>;

	public var locals:Map<String, DeclaredVar>;
	var binops:Map<String, Expr->Expr->Dynamic>;
	#else
	public var customClasses:Hash<Dynamic>;
	public var variables:Hash<Dynamic>;
	public var publicVariables:Hash<Dynamic>;
	public var staticVariables:Hash<Dynamic>;

	public var locals:Hash<DeclaredVar>;
	var binops:Hash<Expr->Expr->Dynamic>;
	#end

	var depth:Int = 0;
	var inTry:Bool;
	var declared:Array<RedeclaredVar>;
	var returnValue:Dynamic;

	var isBypassAccessor:Bool = false;

	public var importEnabled:Bool = true;

	public var allowStaticVariables:Bool = false;
	public var allowPublicVariables:Bool = false;

	public var importBlocklist:Array<String> = [
		// "flixel.FlxG"
	];

	var __instanceFields:Array<String> = [];
	#if hscriptPos
	var curExpr:Expr;
	#end

	public var showPosOnLog:Bool = true;

	public function new() {
		#if haxe3
		locals = new Map();
		#else
		locals = new Hash();
		#end
		declared = new Array();
		resetVariables();
		initOps();
	}

	private function resetVariables() {
		#if haxe3
		customClasses = new Map<String, Dynamic>();
		variables = new Map<String, Dynamic>();
		publicVariables = new Map<String, Dynamic>();
		staticVariables = new Map<String, Dynamic>();
		#else
		customClasses = new Hash();
		variables = new Hash();
		publicVariables = new Hash();
		staticVariables = new Hash();
		#end

		variables.set("null", null);
		variables.set("true", true);
		variables.set("false", false);
		variables.set("trace", UnsafeReflect.makeVarArgs(function(el) {
			var inf = posInfos();
			var v = el.shift();
			if (el.length > 0)
				inf.customParams = el;
			haxe.Log.trace(Std.string(v), inf);
		}));
	}

	public function posInfos():PosInfos {
		#if hscriptPos
		if (curExpr != null)
			return cast {fileName: curExpr.origin, lineNumber: curExpr.line};
		#end
		return cast {fileName: "hscript", lineNumber: 0};
	}

	function initOps():Void {
		var me = this;
		#if haxe3
		binops = new Map();
		#else
		binops = new Hash();
		#end
		binops.set("+", function(e1, e2) return me.expr(e1) + me.expr(e2));
		binops.set("-", function(e1, e2) return me.expr(e1) - me.expr(e2));
		binops.set("*", function(e1, e2) return me.expr(e1) * me.expr(e2));
		binops.set("/", function(e1, e2) return me.expr(e1) / me.expr(e2));
		binops.set("%", function(e1, e2) return me.expr(e1) % me.expr(e2));
		binops.set("&", function(e1, e2) return me.expr(e1) & me.expr(e2));
		binops.set("|", function(e1, e2) return me.expr(e1) | me.expr(e2));
		binops.set("^", function(e1, e2) return me.expr(e1) ^ me.expr(e2));
		binops.set("<<", function(e1, e2) return me.expr(e1) << me.expr(e2));
		binops.set(">>", function(e1, e2) return me.expr(e1) >> me.expr(e2));
		binops.set(">>>", function(e1, e2) return me.expr(e1) >>> me.expr(e2));
		binops.set("==", function(e1, e2) return me.expr(e1) == me.expr(e2));
		binops.set("!=", function(e1, e2) return me.expr(e1) != me.expr(e2));
		binops.set(">=", function(e1, e2) return me.expr(e1) >= me.expr(e2));
		binops.set("<=", function(e1, e2) return me.expr(e1) <= me.expr(e2));
		binops.set(">", function(e1, e2) return me.expr(e1) > me.expr(e2));
		binops.set("<", function(e1, e2) return me.expr(e1) < me.expr(e2));
		binops.set("||", function(e1, e2) return me.expr(e1) == true || me.expr(e2) == true);
		binops.set("&&", function(e1, e2) return me.expr(e1) == true && me.expr(e2) == true);
		binops.set("is", checkIsType);
		binops.set("=", assign);
		binops.set("??", function(e1, e2) {
			var expr1:Dynamic = me.expr(e1);
			return expr1 == null ? me.expr(e2) : expr1;
		});
		binops.set("...", function(e1, e2) return new #if (haxe_211 || haxe3) IntIterator #else IntIter #end(me.expr(e1), me.expr(e2)));
		assignOp("+=", function(v1:Dynamic, v2:Dynamic) return v1 + v2);
		assignOp("-=", function(v1:Float, v2:Float) return v1 - v2);
		assignOp("*=", function(v1:Float, v2:Float) return v1 * v2);
		assignOp("/=", function(v1:Float, v2:Float) return v1 / v2);
		assignOp("%=", function(v1:Float, v2:Float) return v1 % v2);
		assignOp("&=", function(v1, v2) return v1 & v2);
		assignOp("|=", function(v1, v2) return v1 | v2);
		assignOp("^=", function(v1, v2) return v1 ^ v2);
		assignOp("<<=", function(v1, v2) return v1 << v2);
		assignOp(">>=", function(v1, v2) return v1 >> v2);
		assignOp(">>>=", function(v1, v2) return v1 >>> v2);
		assignOp("??" + "=", function(v1, v2) return v1 == null ? v2 : v1);
	}

	function checkIsType(e1:Expr,e2:Expr): Bool {
		var expr1:Dynamic = expr(e1);

		return switch(Tools.expr(e2))
		{
			case EIdent("Class"):
				Std.isOfType(expr1, Class);
			case EIdent("Map") | EIdent("IMap"):
				Std.isOfType(expr1, IMap);
			default:
				var expr2:Dynamic = expr(e2);
				expr2 != null ? Std.isOfType(expr1, expr2) : false;
		}
	}

	public function varExists(name:String):Bool {
		return allowStaticVariables && staticVariables.exists(name) || allowPublicVariables && publicVariables.exists(name) || variables.exists(name);
	}

	public function setVar(name:String, v:Dynamic):Void {
		if (allowStaticVariables && staticVariables.exists(name))
			staticVariables.set(name, v);
		else if (allowPublicVariables && publicVariables.exists(name))
			publicVariables.set(name, v);
		else
			variables.set(name, v);
	}

	// ENUM!!!!
	public function importEnum(enm:Enum<Dynamic>, ?asName:String) {
		if (enm == null) return;
		var enumThingy = {};
		for (c in enm.getConstructors()) {
			try {
				UnsafeReflect.setField(enumThingy, c, enm.createByName(c));
			} catch(e) {
				try {
					UnsafeReflect.setField(enumThingy, c, UnsafeReflect.field(enm, c));
				} catch(ex) throw e;
			}
		}
		if (asName == null){
			var splitName = Type.getEnumName(enm).split(".");
			variables.set(splitName[splitName.length - 1], enumThingy);
		}else{
			variables.set(asName, enumThingy);
		}

		for (i in UnsafeReflect.fields(enumThingy)) {
			variables.set(i, UnsafeReflect.field(enumThingy, i));
		}
	}
	function assign(e1:Expr, e2:Expr):Dynamic {
		var v = expr(e2);
		switch (Tools.expr(e1)) {
			case EIdent(id):
				if (!locals.exists(id)) {
					if (_hasScriptObject && !varExists(id)) {
						if (_scriptObjectType == SObject) {
							UnsafeReflect.setField(scriptObject, id, v);
						} else {
							if (_scriptObjectType == SCustomClass) {
								var obj = cast(scriptObject, IHScriptCustomClassBehaviour);
								if(isBypassAccessor) {
									obj.__allowSetGet = false;
									var res = obj.hset(id, v);
									obj.__allowSetGet = true;
									return res;
								}
								return obj.hset(id, v);
							} else if (_scriptObjectType == SBehaviourClass) {
								return cast(scriptObject, IHScriptCustomBehaviour).hset(id, v);
							}
							if (isBypassAccessor) {
								if (__instanceFields.contains(id)) {
									UnsafeReflect.setField(scriptObject, id, v);
									return v;
								}
							}
							if (__instanceFields.contains(id)) {
								UnsafeReflect.setProperty(scriptObject, id, v);
							} else if (__instanceFields.contains('set_$id')) { // setter
								UnsafeReflect.getProperty(scriptObject, 'set_$id')(v);
							} else setVar(id, v);
						}
					} else {
						setVar(id, v);
					}
				} else {
					var l = locals.get(id);
					l.r = v;
					if (l.depth == 0) setVar(id, v);
				}
				// TODO
			case EField(e, f, s):
				var obj = expr(e);
				if (e == null)
					if (!s) error(EInvalidAccess(f));
					else return null;
				v = set(obj, f, v);
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr)) {
					setMapValue(arr, index, v);
				} else {
					arr[index] = v;
				}

			default:
				error(EInvalidOp("="));
		}
		return v;
	}

	function assignOp(op:String, fop:Dynamic->Dynamic->Dynamic):Void {
		var me = this;
		binops.set(op, function(e1, e2) return me.evalAssignOp(op, fop, e1, e2));
	}

	function evalAssignOp(op:String, fop:Dynamic->Dynamic->Dynamic, e1:Expr, e2:Expr):Dynamic {
		var v;
		switch (Tools.expr(e1)) {
			case EIdent(id):
				var l = locals.get(id);
				v = fop(expr(e1), expr(e2));
				if (l == null) {
					if(_hasScriptObject) {
						if(_scriptObjectType == SObject) {
							UnsafeReflect.setField(scriptObject, id, v);
							return v;
						} else if (_scriptObjectType == SCustomClass) {
							var obj = cast(scriptObject, IHScriptCustomClassBehaviour);
							if(isBypassAccessor) {
								obj.__allowSetGet = false;
								var res = obj.hset(id, v);
								obj.__allowSetGet = true;
								return res;
							}
							return obj.hset(id, v);
						} else if(_scriptObjectType == SBehaviourClass) {
							return cast(scriptObject, IHScriptCustomBehaviour).hset(id, v);
						}

						if (isBypassAccessor) {
							if (__instanceFields.contains(id)) {
								UnsafeReflect.setField(scriptObject, id, v);
								return v;
							}
						}

						if (__instanceFields.contains(id)) {
							UnsafeReflect.setProperty(scriptObject, id, v);
						} else if (__instanceFields.contains('set_$id')) { // setter
							UnsafeReflect.getProperty(scriptObject, 'set_$id')(v);
						} else {
							setVar(id, v);
						}
					}
				} else l.r = v;
			case EField(e, f, s):
				var obj = expr(e);
				if (obj == null)
					if (!s) error(EInvalidAccess(f));
					else return null;
				v = fop(get(obj, f), expr(e2));
				v = set(obj, f, v);
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr)) {
					var map = getMap(arr);

					v = fop(map.get(index), expr(e2));
					map.set(index, v);
				} else {
					v = fop(arr[index], expr(e2));
					arr[index] = v;
				}
			default:
				return error(EInvalidOp(op));
		}
		return v;
	}

	function increment(e:Expr, prefix:Bool, delta:Int):Dynamic {
		#if hscriptPos
		curExpr = e;
		var e = e.e;
		#end
		switch (e) {
			case EIdent(id):
				if(locals.exists(id)) {
					var l = locals.get(id);
					var v:Dynamic = l.r;
					if (prefix) {
						v += delta;
						l.r = v;
					} else
						l.r = v + delta;
					return v;
				} else {
					var v:Dynamic = resolve(id);
					if (prefix) {
						v += delta;
						setVar(id, v);
					} else
						setVar(id, v + delta);
					return v;
				}
			case EField(e, f, s):
				var obj = expr(e);
				if (obj == null)
					if (!s) error(EInvalidAccess(f));
					else return null;
				var v:Dynamic = get(obj, f);
				if (prefix) {
					v += delta;
					set(obj, f, v);
				} else
					set(obj, f, v + delta);
				return v;
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr)) {
					var map = getMap(arr);

					var v = map.get(index);
					if (prefix) {
						v += delta;
						map.set(index, v);
					} else {
						map.set(index, v + delta);
					}
					return v;
				} else {
					var v = arr[index];
					if (prefix) {
						v += delta;
						arr[index] = v;
					} else
						arr[index] = v + delta;
					return v;
				}
			default:
				return error(EInvalidOp((delta > 0) ? "++" : "--"));
		}
	}

	public function execute(expr:Expr):Dynamic {
		depth = 0;
		#if haxe3
		locals = new Map();
		#else
		locals = new Hash();
		#end
		declared = [];
		return exprReturn(expr);
	}

	function exprReturn(e):Dynamic {
		try {
			try {
				return expr(e);
			} catch (e:Stop) {
				switch (e) {
					case SBreak:
						throw "Invalid break";
					case SContinue:
						throw "Invalid continue";
					case SReturn:
						var v = returnValue;
						returnValue = null;
						return v;
				}
			} catch(e) {
				error(ECustom('${e.toString()}'));
				return null;
			}
		} catch(e:Error) {
			if (errorHandler != null)
				errorHandler(e);
			else throw e;
			return null;
		} catch(e) trace(e);
		return null;
	}

	public function duplicate<T>(h:#if haxe3 Map<String, T> #else Hash<T> #end) {
		#if haxe3
		var h2 = new Map();
		#else
		var h2 = new Hash();
		#end
		for (k in h.keys())
			h2.set(k, h.get(k));
		return h2;
	}

	function restore(old:Int):Void {
		while (declared.length > old) {
			var d = declared.pop();
			locals.set(d.n, d.old);
		}
	}

	public inline function error(e:#if hscriptPos ErrorDef #else Error #end, rethrow = false):Dynamic {
		#if hscriptPos var e = new Error(e, curExpr.pmin, curExpr.pmax, curExpr.origin, curExpr.line); #end

		if (rethrow)
			this.rethrow(e)
		else throw e;
		return null;
	}

	inline function warn(e: #if hscriptPos ErrorDef #else Error #end):Dynamic {
		#if hscriptPos var e = new Error(e, curExpr.pmin, curExpr.pmax, curExpr.origin, curExpr.line); #end

		alterhscript.AlterHscript.warn(Printer.errorToString(e, showPosOnLog), #if hscriptPos posInfos() #else null #end);
		return null;
	}
	inline function rethrow(e:Dynamic) {
		#if hl
		hl.Api.rethrow(e);
		#else
		throw e;
		#end
	}

	public function resolve(id:String, doException:Bool = true):Dynamic {
		if (id == null) return null;
		id = StringTools.trim(id);
		if (locals.exists(id))
			return locals.get(id).r;

		if (variables.exists(id))
			return variables.get(id);
		if (publicVariables.exists(id))
			return publicVariables.get(id);
		if (staticVariables.exists(id))
			return staticVariables.get(id);
		if (customClasses.exists(id))
			return customClasses.get(id);

		if (scriptObject != null) {
			// search in object
			if (id == "this") {
				return scriptObject;
			} else if (_scriptObjectType == SObject && UnsafeReflect.hasField(scriptObject, id)) {
				return UnsafeReflect.field(scriptObject, id);
			} else if(_scriptObjectType == SCustomClass) {
				var obj = cast(scriptObject, IHScriptCustomClassBehaviour);
				if(isBypassAccessor) {
					obj.__allowSetGet = false;
					var res = obj.hget(id);
					obj.__allowSetGet = true;
					return res;
				}
				return obj.hget(id);
			} else if(_scriptObjectType == SBehaviourClass) {
				var obj = cast(scriptObject, IHScriptCustomBehaviour);
				return obj.hget(id);
			}
			else {
				if (__instanceFields.contains(id)) {
					return UnsafeReflect.getProperty(scriptObject, id);
				} else if (__instanceFields.contains('get_$id')) { // getter
					return UnsafeReflect.getProperty(scriptObject, 'get_$id')();
				}
			}
		}
		var cl:Class<Dynamic> = Type.resolveClass(id); // now you can do this thing: var a:haxe.io.Path = new haxe.io.Path();  yee
		if (cl == null) cl = Type.resolveClass('${id}_HSC');
		if (cl != null) {
			variables.set(id, cl);
			return cl;
		}

		if (doException)
			error(EUnknownVariable(id));
		return null;
	}

	public function expr(e:Expr):Dynamic {
		#if hscriptPos
		curExpr = e;
		var e = e.e;
		#end
		switch (e) {
			case EClass(name, fields, extend, interfaces):
				if (customClasses.exists(name))
					error(EAlreadyExistingClass(name));

				inline function importVar(thing:String):String {
					if (thing == null) return null;
					final variable:Class<Any> = customClasses.exists(thing) ? null : resolve(thing, false);
					return variable == null ? thing : Type.getClassName(variable);
				}
				customClasses.set(name, new CustomClassHandler(this, name, fields, importVar(extend), [for (i in interfaces) importVar(i)]));
			case EImportStar(pkg):
				#if !macro
				if (!importEnabled) return null;

				var importList:Array<String> = [];
				for(i in hscript.macros.ClassTools.allClassesAvailable) {
					if(!(StringTools.startsWith(i, pkg) && i.substr(pkg.length + 1).indexOf(".") == -1))
						continue;
					if (!StringTools.endsWith(i, "_HSX"))
						importList.push(i);
				}
				for (i in importList)
					if (StringTools.endsWith(i, "_HSC") && importList.contains(i.substr(0, i.length - 4)))
						importList.remove(i); // remove duplicate

				for (i in importList)
					expr(#if hscriptPos {e: EImport(i), pmin: curExpr.pmin, pmax: curExpr.pmax, origin: curExpr.origin, line: curExpr.line, } #else EImport(i) #end);
				#end
				return null;

			case EImport(c, n):
				if (!importEnabled) return null;
				var splitClassName = [for (e in c.split(".")) e.trim()];
				var realClassName = splitClassName.join(".");
				var claVarName = splitClassName[splitClassName.length - 1];
				var toSetName = n != null ? n : claVarName;
				var oldClassName = realClassName;
				var oldSplitName = splitClassName.copy();

				if (variables.exists(toSetName)) // class is already imported
					return null;

				if (importBlocklist.contains(realClassName)) {
					error(ECustom("You cannot add a blacklisted import, for class " + c + toSetName));
					return null;
				}
				var cl = Type.resolveClass(realClassName);
				if (cl == null) cl = Type.resolveClass('${realClassName}_HSC');

				var en = Type.resolveEnum(realClassName);
				// Allow for flixel.ui.FlxBar.FlxBarFillDirection;
				if (cl == null && en == null) {
					if(splitClassName.length > 1) {
						splitClassName.splice(-2, 1); // Remove the last last item
						realClassName = splitClassName.join(".");


						if (importBlocklist.contains(realClassName)) {
							error(ECustom("You cannot add a blacklisted import, for class " + realClassName + toSetName));
							return null;
						}

						cl = Type.resolveClass(realClassName);
						if (cl == null)
							cl = Type.resolveClass('${realClassName}_HSC');
						en = Type.resolveEnum(realClassName);
					}
				}

				if (cl == null && en == null) {
					if (importFailedCallback == null || !importFailedCallback(oldSplitName))
						error(EInvalidClass(oldClassName));
				} else {
					if (en != null) {
						importEnum(en, toSetName);
					} else {
						variables.set(toSetName, cl);
					}
				}

				return null;

			case EConst(c):
				switch (c) {
					case CInt(v): return v;
					case CFloat(f): return f;
					case CString(s): return s;
					#if !haxe3
					case CInt32(v): return v;
					#end
				}
			case EIdent(id):
				return resolve(id);
			case EVar(n, _, e, isPublic, isStatic):
				declared.push({n: n, old: locals.get(n), depth: depth});
				locals.set(n, {r: (e == null) ? null : expr(e), depth: depth});
				if (depth == 0) {
					if(isStatic == true) {
						if(!staticVariables.exists(n)) {
							staticVariables.set(n, locals[n].r);
						}
						return null;
					}
					(isPublic ? publicVariables : variables).set(n, locals[n].r);
				}
				return null;
			case EParent(e):
				return expr(e);
			case EBlock(exprs):
				var old = declared.length;
				var v = null;
				for (e in exprs)
					v = expr(e);
				restore(old);
				return v;
			case EField(e, f, s):
				var field = expr(e);
				if(s && field == null)
					return null;
				return get(field, f);
			case EBinop(op, e1, e2):
				var fop = binops.get(op);
				if (fop == null)
					error(EInvalidOp(op));
				return fop(e1, e2);
			case EUnop(op, prefix, e):
				switch (op) {
					case "!":
						return expr(e) != true;
					case "-":
						return -expr(e);
					case "++":
						return increment(e, prefix, 1);
					case "--":
						return increment(e, prefix, -1);
					case "~":
						#if (neko && !haxe3)
						return haxe.Int32.complement(expr(e));
						#else
						return ~expr(e);
						#end
					default:
						error(EInvalidOp(op));
				}
			case ECall(e, params):
				var args:Array<Dynamic> = [for(p in params) expr(p)];

				switch (Tools.expr(e)) {
					case EField(e, f, s):
						var obj = expr(e);
						if (obj == null) {
							if(s) return null;
							error(EInvalidAccess(f));
						}
						return fcall(obj, f, args);
					default:
						return call(null, expr(e), args);
				}
			case EIf(econd, e1, e2):
				return if (expr(econd) == true) expr(e1) else if (e2 == null) null else expr(e2);
			case EWhile(econd, e):
				whileLoop(econd, e);
				return null;
			case EDoWhile(econd, e):
				doWhileLoop(econd, e);
				return null;
			case EFor(v, it, e, ithv):
				forLoop(v, it, e, ithv);
				return null;
			case EBreak:
				throw SBreak;
			case EContinue:
				throw SContinue;
			case EReturn(e):
				returnValue = e == null ? null : expr(e);
				throw SReturn;
			case EFunction(params, fexpr, name, _, isPublic, isStatic, isOverride):
				var __capturedLocals = duplicate(locals);
				var capturedLocals:Map<String, DeclaredVar> = [];
				for(k=>e in __capturedLocals)
					if (e != null && e.depth > 0)
						capturedLocals.set(k, e);

				var me = this;
				var minParams = 0;
				for (p in params)
					if (!p.opt) minParams++;
				var f = function(args:Array<Dynamic>) {
					if (me.locals == null || me.variables == null) return null;

					if (((args == null) ? 0 : args.length) != params.length) {
						if (args.length < minParams) {
							var str = "Invalid number of parameters. Got " + args.length + ", required " + minParams;
							if (name != null)
								str += " for function '" + name + "'";
							error(ECustom(str));
						}
						// make sure mandatory args are forced
						var args2 = [];
						var extraParams = args.length - minParams;
						var pos = 0;
						for (p in params)
							if (p.opt) {
								if (extraParams > 0) {
									args2.push(args[pos++]);
									extraParams--;
								} else
									args2.push(null);
							} else
								args2.push(args[pos++]);
						args = args2;
					}
					var old = me.locals, depth = me.depth;
					me.depth++;
					me.locals = me.duplicate(capturedLocals);
					for (i in 0...params.length)
						me.locals.set(params[i].name, {r: args[i], depth: depth});
					var r = null;
					var oldDecl = declared.length;
					if (inTry)
						try {
							r = me.exprReturn(fexpr);
						} catch (e:Dynamic) {
							me.locals = old;
							me.depth = depth;
							#if neko
							neko.Lib.rethrow(e);
							#else
							throw e;
							#end
						}
					else
						r = me.exprReturn(fexpr);
					restore(oldDecl);
					me.locals = old;
					me.depth = depth;
					return r;
				};
				var f = UnsafeReflect.makeVarArgs(f);
				if (name != null) {
					if (depth == 0) {
						// global function
						((isStatic && allowStaticVariables) ? staticVariables : ((isPublic && allowPublicVariables) ? publicVariables : variables)).set(name, f);
					} else {
						// function-in-function is a local function
						declared.push({n: name, old: locals.get(name), depth: depth});
						var ref:DeclaredVar = {r: f, depth: depth};
						locals.set(name, ref);
						capturedLocals.set(name, ref); // allow self-recursion
					}
				}
				return f;
			case EArrayDecl(arr, wantedType):
				var isMap = false;
				var isTypeMap = false;
				if(!isMap && wantedType != null) {
					isMap = wantedType.match(CTPath(["Map"], [_, _]));
					isTypeMap = true;
				} else {
					isMap = arr.length > 0 && Tools.expr(arr[0]).match(EBinop("=>", _));
				}
				if (isMap) {
					var isAllString:Bool = true;
					var isAllInt:Bool = true;
					var isAllObject:Bool = true;
					var isAllEnum:Bool = true;
					var keys:Array<Dynamic> = [];
					var values:Array<Dynamic> = [];
					for (e in arr) {
						switch (Tools.expr(e)) {
							case EBinop("=>", eKey, eValue): {
								var key:Dynamic = expr(eKey);
								var value:Dynamic = expr(eValue);
								isAllString = isAllString && (key is String);
								isAllInt = isAllInt && (key is Int);
								isAllObject = isAllObject && UnsafeReflect.isObject(key);
								isAllEnum = isAllEnum && UnsafeReflect.isEnumValue(key);
								keys.push(key);
								values.push(value);
							}
							default: throw("=> expected");
						}
					}

					if(isTypeMap) {
						if(wantedType != null) {
							isAllString = wantedType.match(CTPath(["Map"], [CTPath(["String"], _), _]));
							isAllInt = wantedType.match(CTPath(["Map"], [CTPath(["Int"], _), _]));
							if(isAllString || isAllInt) {
								isAllObject = false;
								isAllEnum = false;
							} else {
								if(!isAllObject && !isAllEnum) {
									throw("Unknown Type Key");
								}
							}
						}
					}

					var map:Dynamic = {
						if (isAllInt)
							new haxe.ds.IntMap<Dynamic>();
						else if (isAllString)
							new haxe.ds.StringMap<Dynamic>();
						else if (isAllEnum)
							new haxe.ds.EnumValueMap<Dynamic, Dynamic>();
						else if (isAllObject)
							new haxe.ds.ObjectMap<Dynamic, Dynamic>();
						else
							throw 'Inconsistent key types';
					}
					for (n in 0...keys.length) {
						setMapValue(map, keys[n], values[n]);
					}
					return map;
				} else {
					return [for (e in arr) expr(e)];
				}
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr)) {
					return getMapValue(arr, index);
				} else {
					return arr[index];
				}
			case ENew(cl, params):
				var a = [];
				for (e in params)
					a.push(expr(e));
				return cnew(cl, a);
			case EThrow(e):
				throw expr(e);
			case ETry(e, n, _, ecatch):
				var old = declared.length;
				var oldTry = inTry;
				try {
					inTry = true;
					var v:Dynamic = expr(e);
					restore(old);
					inTry = oldTry;
					return v;
				} catch (err:Stop) {
					inTry = oldTry;
					throw err;
				} catch (err:Dynamic) {
					// restore vars
					restore(old);
					inTry = oldTry;
					// declare 'v'
					declared.push({n: n, old: locals.get(n), depth: depth});
					locals.set(n, {r: err, depth: depth});
					var v:Dynamic = expr(ecatch);
					restore(old);
					return v;
				}
			case EObject(fl):
				var o = {};
				for (f in fl)
					UnsafeReflect.setField(o, f.name, expr(f.e));
				return o;
			case ETernary(econd, e1, e2):
				return if (expr(econd) == true) expr(e1) else expr(e2);
			case ESwitch(e, cases, def):
				var val:Dynamic = expr(e);
				var match = false;
				for (c in cases) {
					for (v in c.values)
						if (expr(v) == val) {
							match = true;
							break;
						}
					if (match) {
						val = expr(c.expr);
						break;
					}
				}
				if (!match)
					val = def == null ? null : expr(def);
				return val;
			case EMeta(name, args, e):
				if (onMetadata != null) return onMetadata(name, args, e);
				var oldAccessor = isBypassAccessor;
				if(name == ":bypassAccessor") {
					isBypassAccessor = true;
				}
				var val = expr(e);

				isBypassAccessor = oldAccessor;
				return val;
			case ECheckType(e, _):
				return expr(e);
		}
		return null;
	}

	function doWhileLoop(econd:Expr, e:Expr):Void {
		var old = declared.length;
		do {
			try {
				expr(e);
			} catch (err:Stop) {
				switch (err) {
					case SContinue:
					case SBreak:
						break;
					case SReturn:
						throw err;
				}
			}
		} while (expr(econd) == true);
		restore(old);
	}

	function whileLoop(econd:Expr, e:Expr):Void {
		var old = declared.length;
		while (expr(econd) == true) {
			try {
				expr(e);
			} catch (err:Stop) {
				switch (err) {
					case SContinue:
					case SBreak:
						break;
					case SReturn:
						throw err;
				}
			}
		}
		restore(old);
	}

	function makeIterator(v:Dynamic, ?allowKeyValue = false):Iterator<Dynamic> {
		#if ((flash && !flash9) || (php && !php7 && haxe_ver < '4.0.0'))
		if (v.iterator != null)
			v = v.iterator();
		#else
		if(allowKeyValue) {
			try
				v = v.keyValueIterator()
			catch (e:Dynamic) {};
		}

		if(v.hasNext == null || v.next == null) {
			try
				v = v.iterator()
			catch (e:Dynamic) {};
		}
		#end
		if (v.hasNext == null || v.next == null)
			error(EInvalidIterator(v));
		return v;
	}

	function forLoop(n:String, it:Expr, e:Expr, ?ithv:String):Void {
		var isKeyValue = ithv != null;
		var old = declared.length;
		if(isKeyValue)
			declared.push({n: ithv, old: locals.get(ithv), depth: depth});
		declared.push({n: n, old: locals.get(n), depth: depth});
		var it = makeIterator(expr(it), isKeyValue);
		var _hasNext = it.hasNext;
		var _next = it.next;
		var next;
		while (_hasNext()) {
			next = _next();
			if(isKeyValue)
				locals.set(ithv, {r: next.key, depth: depth});
			locals.set(n, {r: isKeyValue ? next.value : next, depth: depth});
			try {
				expr(e);
			} catch (err:Stop) {
				switch (err) {
					case SContinue:
					case SBreak:
						break;
					case SReturn:
						throw err;
				}
			}
		}
		restore(old);
	}

	inline function getMap(map:Dynamic):IMap<Dynamic, Dynamic> {
		return cast(map, IMap<Dynamic, Dynamic>);
	}

	inline function isMap(o:Dynamic):Bool {
		return (o is IMap);
	}

	inline function getMapValue(map:Dynamic, key:Dynamic):Dynamic {
		return cast(map, IMap<Dynamic, Dynamic>).get(key);
	}

	inline function setMapValue(map:Dynamic, key:Dynamic, value:Dynamic):Void {
		cast(map, IMap<Dynamic, Dynamic>).set(key, value);
	}

	public static var getRedirects:Map<String, (Dynamic, String)->Dynamic> = [];
	public static var setRedirects:Map<String, (Dynamic, String, Dynamic)->Dynamic> = [];

	private static var _getRedirect:Dynamic->String->Dynamic;
	private static var _setRedirect:Dynamic->String->Dynamic->Dynamic;

	public var useRedirects:Bool = false;

	static function getClassType(o:Dynamic, ?cls:Class<Any>):Null<String> {
		return switch (Type.typeof(o)) {
			case TNull: "Null";
			case TInt: "Int";
			case TFloat: "Float";
			case TBool: "Bool";
			case _:
				if (cls == null)
					cls = Type.getClass(o);
				cls != null ? Type.getClassName(cls) : null;
		};
	}
	function get(o:Dynamic, f:String):Dynamic {
		if (o == null)
			error(EInvalidAccess(f));
		var cls = Type.getClass(o);
		if (useRedirects && {
			var cl:Null<String> = getClassType(o, cls);
			cl != null && getRedirects.exists(cl) && (_getRedirect = getRedirects[cl]) != null;
		}) {
			return _getRedirect(o, f);
		} else if (o is IHScriptCustomBehaviour) {
			var obj = cast(o, IHScriptCustomBehaviour);
			return obj.hget(f);
		}
		var v = null;
		if(isBypassAccessor) {
			if ((v = Reflect.field(o, f)) == null)
				v = Reflect.field(cls, f);
		}

		if(v == null) {
			if ((v = Reflect.getProperty(o, f)) == null)
				v = Reflect.getProperty(cls, f);
		}
		return v;
	}

	function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if (o == null)
			error(EInvalidAccess(f));

		if (useRedirects && {
			var cl:Null<String> = getClassType(o);
			cl != null && setRedirects.exists(cl) && (_setRedirect = setRedirects[cl]) != null;
		})
			return _setRedirect(o, f, v);
		else if (o is IHScriptCustomBehaviour)
			return cast(o, IHScriptCustomBehaviour).hset(f, v);
		if(isBypassAccessor)
			UnsafeReflect.setField(o, f, v);
		else
			UnsafeReflect.setProperty(o, f, v);
		return v;
	}

	function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {
		if(o == CustomClassHandler.staticHandler && scriptObject != null) {
			return UnsafeReflect.callMethod(scriptObject, UnsafeReflect.field(scriptObject, "_HX_SUPER__" + f), args);
		}
		return call(o, get(o, f), args);
	}

	function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
		if(f == CustomClassHandler.staticHandler) {
			return null;
		}
		return UnsafeReflect.callMethod(o, f, args);
	}

	function cnew(cl:String, args:Array<Dynamic>):Dynamic {
		var cl:String = cast cl;
		var c:Dynamic = resolve(cl);
		if (c == null)
			c = Type.resolveClass(cl);
		return (c is IHScriptCustomConstructor) ? cast(c, IHScriptCustomConstructor).hnew(args) : Type.createInstance(c, args);
	}
}