package hscript.macros;

#if macro
import Type.ValueType;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.Printer;
import haxe.macro.Compiler;
import haxe.macro.ComplexTypeTools;

using StringTools;
using haxe.macro.PositionTools;

class AbstractHandler {
	public static inline final CLASS_SUFFIX = "_HSA";

	public static function init() {
		#if !display
		if(Context.defined("display")) return;
		//for(apply in Config.ALLOWED_ABSTRACT_AND_ENUM) {
			//}
		Compiler.addGlobalMetadata("", '@:build(hscript.macros.AbstractHandler.build())');

		//var module = cl.module + cl.name;
		#end
	}

	static var abstracts = new Map<String, {
		
	}>();

	static function finalizeAbstract(a:AbstractType) {
		var name = a.name;
		if(name.endsWith(CLASS_SUFFIX)) return; // !name.endsWith("_Impl_") || 
		if(name != "NodeListAccess") return;

		Sys.println("");
		Sys.println("");
		Sys.println("");
		Sys.println("");
		Sys.println("");

		//Sys.println("name: " + a.name);
		//Sys.println("module: " + a.module);

		Sys.println(MacroPrinter.convertAbstractTypeToString(a));

		//trace("buildAbstract", a);
	}

	static var currentSelf = "";

	static function oldTypeToString(t:Type, selfCheck:String = null):String {
		var str = switch(t) {
			case TInst(_.get() => t, params):
				var str = "";
				if(t.pack.length > 0) {
					str += t.pack.join(".") + ".";
				}
				str += t.name;
				if(t.params != null && t.params.length > 0) {
					str += "<" + t.params.map((v)->oldTypeToString(v.t, t.name + "." + v.name)).join(", ") + ">";
				}
				//if(t.params.length > 0) {
				//	throw "Params not supported yet " + t.name + " " + t.params;
				//}
				str;
			case TAbstract(_.get() => t, params):
				var str = "";
				if(t.pack.length > 0) {
					str += t.pack.join(".") + ".";
				}
				str += t.name;
				if(t.params != null && t.params.length > 0) {
					str += "<" + t.params.map((v)->oldTypeToString(v.t, t.name + "." + v.name)).join(", ") + ">";
				}
				//if(t.params.length > 0) {
				//	throw "Params not supported yet " + t.name + " " + t.params;
				//}
				str;
			case TEnum(_.get() => t, params):
				var str = "";
				if(t.pack.length > 0) {
					str += t.pack.join(".") + ".";
				}
				str += t.name;
				if(t.params != null && t.params.length > 0) {
					str += "<" + t.params.map((v)->oldTypeToString(v.t, t.name + "." + v.name)).join(", ") + ">";
				}
				//if(t.params.length > 0) {
				//	throw "Params not supported yet " + t.name + " " + t.params;
				//}
				str;
			case TType(_.get() => t, params):
				var str = "";
				if(t.pack.length > 0) {
					str += t.pack.join(".") + ".";
				}
				str += t.name;
				if(t.params != null && t.params.length > 0) {
					str += "<" + t.params.map((v)->oldTypeToString(v.t, t.name + "." + v.name)).join(", ") + ">";
					//trace("TType", str);
				}
				str;
			case TAnonymous(_.get() => t):
				//var str = "Dynamic {"+t.fields.map((f)->f.name).join(", ")+"}";
				//str += t.name;
				var str = "{ ";
				var first = true;
				for(f in t.fields) {
					if(!first) str += ", ";
					first = false;
					str += f.name + ":" + oldTypeToString(f.type);
				}
				str += " }";
				//trace("TAnonymous", str);
				str;
			case TDynamic(t):
				var str = "Dynamic";
				if(t != null) {
					str += "<" + oldTypeToString(t) + ">";
				}
				str;
			default:
				Sys.println("Unknown type " + Std.string(t));
				null;
		}

		if(selfCheck != null) {
			if(str == selfCheck) {
				return selfCheck;
				//return currentSelf;
			}
		}
		return str;
	}

	static function getResolvedType(t:ComplexType):String {
		if(t == null) return null;

		try {
			//var type = Context.getType(checkType);
			var paramFree = switch(t) {
				case TPath(t):
					//trace(t);
					TPath({
						name: t.name,
						pack: t.pack,
						params: t.params,
						sub: t.sub
					});
				case TAnonymous(a):
					t;
				case TFunction(args, ret):
					t;
				default:
					trace("");
					trace(ComplexTypeTools.toString(t));
					throw "Unknown type " + Std.string(t);
			}
			var type = ComplexTypeTools.toType(paramFree);
			var strType = oldTypeToString(type);
			if(strType != null) return strType;
		} catch(e:Dynamic) {
			Sys.println(e);
			Sys.println(ComplexTypeTools.toString(t));
			Sys.println(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
		}

		return MacroPrinter.typeToString(t);
	}

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var clRef = Context.getLocalClass();
		if (clRef == null) return fields;
		var cl = clRef.get();

		if(cl.isExtern) return fields;

		//if(cl.name != "Access_Impl_") return fields;
		//if(cl.name != "DrawQuadsView_Impl_") return fields;

		if(cl.name.endsWith("_Impl_") && !cl.name.endsWith(CLASS_SUFFIX)) // && ["Access_Impl_", "AttribAccess_Impl_"].contains(cl.name))
		{
			//if(!initialized) {
			//	initialized = true;
			//	Context.onAfterTyping(function(mods) {
			//		for(mod in mods) {
			//			switch(mod) {
			//				case TAbstract(_.get() => a):
			//					//trace("onAfterTyping", a);
			//					finalizeAbstract(a);
			//					//ab = a;
			//				default:
			//				//	return;
			//			}
			//		}
			//	});
			//}

			currentSelf = cl.name.substr(0, cl.name.length - "_Impl_".length);

			var funcInfos = [];
			//for(f in fields) {
			//	trace(f.name, f.kind);
			//}
			for(f in fields) {
				if(f.name.startsWith("__abstract_helper"))
					continue;
				//if(f.name != "escapes")
				//	continue;
				//trace(f);
				//trace(
				//MacroPrinter.convertFieldToString(f, cl.module + "." + cl.name)
				//);
				//trace();
				//continue;
				switch(f.kind) {
					case FFun(fun):
						if(fun.expr != null) {
							var obj:Dynamic = {
								name: f.name,
								args: [for(a in fun.args) {
									name: a.name,
									opt: a.opt,
									type: getResolvedType(a.type),
									//value: a.value,
									//meta: a.meta,
								}],
								ret: fun.ret,
								op: {
									var op = null;
									//trace("");
									//trace("");
									//trace("");
									//trace(f.name, f.meta);
									//trace(f.name, fun);
									for(m in f.meta) {
										if(m.name == ":op") {
											switch (m.params[0].expr) {
												case EField(_.expr => EConst(CIdent("a")), "b"):
													op = "a.b";
												case EArrayDecl([]):
													op = "[]";
												case EUnop(o, suffix, _.expr => EConst(CIdent("A"))):
													var opStr = switch(o) {
														case OpNeg: "-";
														case OpIncrement: "++";
														case OpDecrement: "--";
														case OpNot: "!";
														case OpNegBits: "~";
														case OpSpread: "...";
													}
													if(suffix) {
														op = "A" + opStr;
													} else {
														op = opStr + "A";
													}
												case EBinop(o, _.expr => EConst(CIdent("A")), _.expr => EConst(CIdent("B"))):
													var opStr = getBinopStr(o);
													op = "A " + opStr + " B";
												#if (haxe >= "4.3.0")
												case ECall(_.expr => EConst(CIdent("a")), []):
													op = "a()";
												#end
												default:
													trace(f.name, cl.module);
													throw "Unknown op " + MacroPrinter.convertExprToString(m.params[0]) + "\n in " + f.name + " in " + cl.module;
											}
											//trace(op, convertExprToString(m.params[0]));
											//trace(Type.typeof(m.params[0]));
											//switch (m.params[0].expr) {
											//	case EConst(CIdent(_i)):
											//		id = _i;
											//	default:
											//}
										}
									}
									op;
								}
							}

							if(obj.ret == null && f.name.startsWith("get_")) {
								var v = getVarFromFields(fields, f.name.substr(4));
								var type = getTypeFromField(v);
								//Sys.println("getter " + f.name + " " + getResolvedType(type) + " " + type);
								obj.ret = type;
							} else if(obj.ret == null && f.name.startsWith("set_")) {
								var v = getVarFromFields(fields, f.name.substr(4));
								var type = getTypeFromField(v);
								//Sys.println("setter " + f.name + " " + getResolvedType(type) + " " + type);
								obj.ret = type;
							} else {
								if(obj.ret != null) {
									//Sys.println("normal field " + f.name + " " + getResolvedType(obj.ret) + " " + obj.ret);
								}
							}

							if(obj.name == "_new")
								obj.name = "new";

							obj.ret = getResolvedType(obj.ret);

							trace("FFun", obj);
							funcInfos.push(obj);
							//trace(cl.name, obj);
						}
					default:
				}
				//funcInfos.push([f.name, ]);
			}

			//trace(funcInfos);

			//trace(cl.pos);

			var shadowClass = macro class {

			};

			shadowClass.kind = TDClass(null, [
				//{name: "IHScriptCustomBehaviour", pack: ["hscript"]},
				//{name: "IHScriptCustomClassBehaviour", pack: ["hscript"]}
			], false, true, false);
			shadowClass.name = '${cl.name.substr(0, cl.name.length - "_Impl_".length)}$CLASS_SUFFIX';
			//trace(shadowClass.name);
			var imports = Context.getLocalImports().copy();
			Utils.setupMetas(shadowClass, [], false);
			//Utils.processImport(imports, "hscript.utils.UnsafeReflect", "UnsafeReflect");

			shadowClass.fields.push({
				name: "__abstract_helper",
				pos: cl.pos,
				access: [APublic, AStatic],
				kind: FFun({
					ret: TPath({name: 'Dynamic', pack: []}),
					params: [],
					expr: macro {
						return {
							funcs: $v{funcInfos}
						};
					},
					args: [
					]
				})
			});
			//trace(cl.name, fields.length);

			var moduleName = cl.module;
			//if(cl.module.lastIndexOf(".") > 0) {
			//	moduleName += cl.module.substr(0, cl.module.lastIndexOf(".")) + ".";
			//}
			//moduleName += "_" + cl.module.split(".").pop();
			Context.defineModule(moduleName, [shadowClass], imports);
			//trace(moduleName);

			var printer = new haxe.macro.Printer();
			var code = printer.printTypeDefinition(shadowClass);
			//trace(code);


			return fields;
		}

		return fields;
	}

	static var initialized = false;

	static function getBinopStr(op:Binop):String {
		return switch(op) {
			case OpAdd: "+";
			case OpSub: "-";
			case OpMult: "*";
			case OpDiv: "/";
			case OpMod: "%";
			case OpEq: "==";
			case OpNotEq: "!=";
			case OpGt: ">";
			case OpGte: ">=";
			case OpLt: "<";
			case OpLte: "<=";
			case OpAnd: "&";
			case OpOr: "|";
			case OpXor: "^";
			case OpShl: "<<";
			case OpShr: ">>";
			case OpUShr: ">>>";
			case OpBoolAnd: "&&";
			case OpBoolOr: "||";
			case OpAssign: "=";
			case OpArrow: "=>";
			case OpAssignOp(op):
				getBinopStr(op) + "=";
			case OpIn: "in";
			case OpInterval: "...";
		}
	}

	static function getVarFromFields(fields:Array<Field>, name:String):Field {
		for(f in fields) {
			if(f.name == name) {
				switch(f.kind) {
					case FProp(_, _, _, _):
						return f;
					default:
				}
			}
		}
		return null;
	}

	static function getTypeFromField(field:Field):ComplexType {
		//if(field == null) return null;
		return switch(field.kind) {
			case FProp(_, _, t, _): t;
			case FVar(t, _): t;
			case FFun(f): f.ret;
			default: null;
		}
	}
}
#end