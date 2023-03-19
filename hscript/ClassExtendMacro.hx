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

	public static inline final CLASS_PREFIX = "_HX_SUPER__";

	public function new(className:String, usedClass:Class<Dynamic>) {
		this.className = className;
		this.usedClass = usedClass;
	}

	public static function init() {
		Compiler.addGlobalMetadata('flixel', '@:build(hscript.ClassExtendMacro.build())');
		//Compiler.addGlobalMetadata('openfl.display.BlendMode', '@:build(hscript.UsingHandler.build())');
		trace("TEST");
	}

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var clRef = Context.getLocalClass();
		if (clRef == null) return fields;
		var cl = clRef.get();

		//return fields;

		if (!cl.name.endsWith("_Impl_")) {//(/* cl.name.startsWith("Flx") && */ cl.name.endsWith("_Impl_") && cl.params.length <= 0 && !cl.meta.has(":multiType")) {
			var metas = cl.meta.get();

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
			shadowClass.name = '${cl.name}_HSX'; // Hscript Extra

			//trace(cast(cl.kind, TypeDefinition));

			//var clk:TypeDefinition = cast cl.kind;

			//trace(clk);
			trace(cl.name, cl.kind.getName(), cl.kind.getParameters());

			if(cl.params.length > 0) {
				return fields;
			}

			var superClass:haxe.macro.TypePath = {
				pack: cl.pack,
				name: cl.name,
				//params: shadowClass.params
			}
			shadowClass.kind = TDClass(superClass, [], false, false, false);
			//shadowClass.extends
			var newFuncNames = [];

			for(f in fields)
				switch(f.kind) {
					case FFun(fun):
						if (!f.access.contains(AStatic) && f.access.contains(AOverride)) {
							if (fun.expr != null) {
								//trace(fun.expr);
								var newFuncName = CLASS_PREFIX + f.name;

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

								trace("");
								trace(fun.args);

								var args:Array<String> = [];

								//if(fun.args.length <= 1) {
								//	if(fun.args.length == 1) {
								//		if(!fun.args[0].type.match(TPath({name: "Float"}))) {
								//			continue;
								//		}
								//	}
								//}

								for(arg in fun.args) {
									args.push(arg.name);
								}

								var myFunc:Function = /*fun.args.length > 0 ?
								{
									expr: macro return super.$name(
										Width
									),
									//expr: macro return super.$name($b{[for(arg in fun.args) macro $v{arg.name} ]}),
									ret: fun.ret,
									args: fun.args
								}
								:*/{
									expr: macro return super.$name(/*$a{[for(arg in fun.args) macro $i{arg.name}]}*/),//macro return super.$name(),
									//expr: macro return $p{["super",name]}(/*$a{[for(arg in fun.args) macro $i{arg.name}]}*/),//macro return super.$name(),
									ret: fun.ret,
									args: fun.args
								};

								var aa = myFunc.expr;
								var aa = aa.expr.getParameters();
								var aa:ExprDef = cast aa[0].expr;
								var arguments = aa.getParameters()[1];

								trace(arguments);

								for(i=>arg in fun.args) {
									arguments[i] = macro $i{arg.name};
								}

								trace(arguments);

								//expr: macro return super.$name(macro $p{args}),
								// //macro return $p{["super", "super", name]}(),

								newFuncNames.push(name);

								var newField = {
									name: newFuncName,
									doc: null,
									meta: [],
									access: newAccess,
									kind: FFun(myFunc),
									//kind: FVar(macro:String, macro "my default"),
									pos: Context.currentPos()
								};
								shadowClass.fields.push(newField);
							}
						}
					/*case FProp(get, set, t, e):
						if (get == "default" && (set == "never" || set == "null"))
							shadowClass.fields.push(f);*/
					/*case FVar(t, e):
						if (f.access.contains(AStatic) || cl.meta.has(":enum") || f.name.toUpperCase() == f.name) {
							var name:String = f.name;
							var enumType:String = cl.name;
							var pack = cl.module.split(".");
							pack.pop();
							var complexType:ComplexType = t != null ? t : (name.contains("REGEX") ? TPath({
								name: "EReg",
								pack: []
							}) : TPath({
								name: cl.name.substr(0, cl.name.length - 6),
								pack: pack}));
							var field:Field = {
								pos: f.pos,
								name: f.name,
								meta: f.meta,
								kind: FVar(complexType, {
									pos: Context.currentPos(),
									expr: ECast(e, complexType)
								}),
								doc: f.doc,
								access: [APublic, AStatic]
							}

							shadowClass.fields.push(field);
						}*/
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