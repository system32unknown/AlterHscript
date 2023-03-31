package hscript;

import Type.ValueType;
#if macro
import haxe.macro.ComplexTypeTools;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;
import haxe.macro.Compiler;
import Sys;

using StringTools;

class ClassExtendMacro {
	public var usedClass:Class<Dynamic>;
	public var className:String;

	public static inline final FUNC_PREFIX = "_HX_SUPER__";
	public static inline final CLASS_SUFFIX = "_HSX";

	public function new(className:String, usedClass:Class<Dynamic>) {
		this.className = className;
		this.usedClass = usedClass;
	}

	public static function init() {
		//Compiler.addGlobalMetadata('funkin', '@:build(hscript.ClassExtendMacro.build())');
		Compiler.addGlobalMetadata('flixel', '@:build(hscript.ClassExtendMacro.build())');
		//Compiler.addGlobalMetadata('openfl.display.BlendMode', '@:build(hscript.UsingHandler.build())');
		trace("TEST");
	}

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var clRef = Context.getLocalClass();
		if (clRef == null) return fields;
		var cl = clRef.get();

		if (!cl.name.endsWith("_Impl_") && !cl.name.endsWith(CLASS_SUFFIX) && !cl.name.endsWith("__Softcoded")) {//(/* cl.name.startsWith("Flx") && */ cl.name.endsWith("_Impl_") && cl.params.length <= 0 && !cl.meta.has(":multiType")) {
			var metas = cl.meta.get();

			if(cl.params.length > 0) {
				return fields;
			}

			var shadowClass = macro class {

			};
			shadowClass.params = switch(cl.params.length) {
				case 0:
					null;
				case 1:
					[
						{
							name: "T",
						}
					];
				default:
					[for(k=>e in cl.params) {
						name: "T" + Std.int(k+1)
					}];
			};
			shadowClass.name = cl.name + CLASS_SUFFIX; // Hscript Extra

			var superClass:haxe.macro.TypePath = {
				pack: cl.pack,
				name: cl.name,
				//params: shadowClass.params
			}
			shadowClass.kind = TDClass(superClass, [], false, false, false);

			var newFuncNames = [];

			for(f in fields)
				switch(f.kind) {
					case FFun(fun):
						if (!f.access.contains(AStatic) && f.name != "new" && !f.access.contains(ADynamic)) { /* || !cl.name.endsWith(CLASS_SUFFIX)*/
							if (fun.params.length > 0) continue;
							if (fun.expr != null) {
								//trace(fun.expr);
								var newFuncName = FUNC_PREFIX + f.name;

								var newAccess = f.access.copy();
								var needsOverride = false;
								for(cf in fields)
									switch(cf.kind) {
										case FFun(cfun):
											if (!cf.access.contains(AStatic)/* && cf.access.contains(AOverride)*/) {
												if(cf.name == newFuncName) {
													needsOverride = true;
													break;
												}
											}
										default:
									}

								if(!needsOverride) { // by default contains AOverride, so we remove it if the class doesnt have the same name
									newAccess.remove(AOverride);
								}

								var name = f.name;

								//trace("");
								///trace(fun.args);

								var myFunc:Function = null;

								if(fun.ret.match(TPath({name: "Void"}))) {
									myFunc = {
										expr: macro super.$name(),
										ret: fun.ret,
										args: fun.args,
										params: fun.params,
									};

									var arguments = myFunc.expr.expr.getParameters()[1];

									for(i=>arg in fun.args) {
										arguments[i] = macro $i{arg.name};
									}
								} else {
									myFunc = {
										expr: macro return super.$name(),
										ret: fun.ret,
										args: fun.args,
										params: fun.params,
									};

									var aa = myFunc.expr.expr.getParameters();
									var aa:ExprDef = cast aa[0].expr;
									var arguments = aa.getParameters()[1];

									//trace(arguments);

									for(i=>arg in fun.args) {
										arguments[i] = macro $i{arg.name};
									}
								}

								newFuncNames.push(name);

								var newField = {
									name: newFuncName,
									doc: null,
									meta: [],
									access: newAccess,
									kind: FFun(myFunc),
									pos: Context.currentPos()
								};
								shadowClass.fields.push(newField);
							}
						}
					default:
				}

			if(shadowClass.fields.length > 0) {
				trace("Defining Class: " + shadowClass.name + " containing " + newFuncNames);
				Context.defineModule(cl.module, [shadowClass], Context.getLocalImports());
			}
		}

		return fields;
	}
}
#else
class ClassExtendMacro {
	public var usedClass:Class<Dynamic>;
	public var className:String;
}
#end