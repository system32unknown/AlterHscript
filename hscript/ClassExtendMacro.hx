package hscript;

import haxe.macro.Type.ClassType;
#if macro
import Type.ValueType;
import haxe.macro.Expr.Function;
import haxe.macro.Expr;
import haxe.macro.*;
import Sys;

using StringTools;

class ClassExtendMacro {
	public var usedClass:Class<Dynamic>;
	public var className:String;

	public static inline final FUNC_PREFIX = "_HX_SUPER__";
	public static inline final CLASS_SUFFIX = "_HSX";

	public static var applyOn:Array<String> = ["flixel", "funkin"];
	public static var unallowedMetas:Array<String> = [":bitmap", ":noCustomClass"];

	public function new(className:String, usedClass:Class<Dynamic>) {
		this.className = className;
		this.usedClass = usedClass;
	}

	public static function init() {
		Compiler.addGlobalMetadata('funkin', '@:build(hscript.ClassExtendMacro.build())');
		Compiler.addGlobalMetadata('flixel', '@:build(hscript.ClassExtendMacro.build())');
		trace("TEST");
	}

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var clRef = Context.getLocalClass();
		if (clRef == null) return fields;
		var cl = clRef.get();

		if (cl.isAbstract || cl.isExtern || cl.isFinal || cl.isInterface) return fields;
		if (!cl.name.endsWith("_Impl_") && !cl.name.endsWith(CLASS_SUFFIX) && !cl.name.endsWith("__Softcoded") && !cl.name.endsWith("_HSC")) {//(/* cl.name.startsWith("Flx") && */ cl.name.endsWith("_Impl_") && cl.params.length <= 0 && !cl.meta.has(":multiType")) {
			var metas = cl.meta.get();

			for(m in metas)
				if (unallowedMetas.contains(m.name))
					return fields;
			
			if(cl.params.length > 0) {
				return fields;
			}
			
			var shadowClass = macro class {

			};

			for(f in fields.copy()) {
				if (f.name == "new")
					continue;
				if (f.name.startsWith(FUNC_PREFIX))
					continue;
				if (f.access.contains(ADynamic) || f.access.contains(AStatic) || f.access.contains(AExtern) || f.access.contains(AInline))
					continue;

				switch(f.kind) {
					case FFun(fun):
						if (fun.params != null && fun.params.length > 0)
							continue;

						var overrideExpr:Expr;
						var returns:Bool = !fun.ret.match(TPath({name: "Void"}));
						
						if (returns) {
							overrideExpr = macro {
								var name:String = ${{
									expr: EConst(CString(f.name)),
									pos: Context.currentPos()
								}};
								var v;

								if (__interp != null && __interp.variables.exists(name) && Reflect.isFunction(v = __interp.variables.get(name))) {
									return ${{
										expr: ECall({
											pos: Context.currentPos(),
											expr: EConst(CIdent("v"))
										}, fun.args != null ? [for(a in fun.args) {
											pos: Context.currentPos(),
											expr: EConst(CIdent(a.name))
										}] : []),
										pos: Context.currentPos()
									}}
								}
								return ${{
										expr: ECall({
											pos: Context.currentPos(),
											expr: EField({
												pos: Context.currentPos(),
												expr: EConst(CIdent("super"))
											}, f.name)
										}, fun.args != null ? [for(a in fun.args) {
											pos: Context.currentPos(),
											expr: EConst(CIdent(a.name))
										}] : []),
										pos: Context.currentPos()
									}}
							};
						} else {
							overrideExpr = macro {
								var name:String = ${{
									expr: EConst(CString(f.name)),
									pos: Context.currentPos()
								}};
								var v:Dynamic;

								if (__interp != null && __interp.variables.exists(name) && Reflect.isFunction(v = __interp.variables.get(name))) {
									${{
										expr: ECall({
											pos: Context.currentPos(),
											expr: EConst(CIdent("v"))
										}, fun.args != null ? [for(a in fun.args) {
											pos: Context.currentPos(),
											expr: EConst(CIdent(a.name))
										}] : []),
										pos: Context.currentPos()
									}}
								} else {
									${{
										expr: ECall({
											pos: Context.currentPos(),
											expr: EField({
												pos: Context.currentPos(),
												expr: EConst(CIdent("super"))
											}, f.name)
										}, fun.args != null ? [for(a in fun.args) {
											pos: Context.currentPos(),
											expr: EConst(CIdent(a.name))
										}] : []),
										pos: Context.currentPos()
									}}
								}
							};
						}

						var superFuncExpr:Expr = returns ? (macro return ${{
							expr: ECall({
								pos: Context.currentPos(),
								expr: EField({
									pos: Context.currentPos(),
									expr: EConst(CIdent("super"))
								}, f.name)
							}, fun.args != null ? [for(a in fun.args) {
								pos: Context.currentPos(),
								expr: EConst(CIdent(a.name))
							}] : []),
							pos: Context.currentPos()
						}}) : {
							expr: ECall({
								pos: Context.currentPos(),
								expr: EField({
									pos: Context.currentPos(),
									expr: EConst(CIdent("super"))
								}, f.name)
							}, fun.args != null ? [for(a in fun.args) {
								pos: Context.currentPos(),
								expr: EConst(CIdent(a.name))
							}] : []),
							pos: Context.currentPos()
						};

						var func:Function = {
							ret: fun.ret,
							params: fun.params.copy(),
							expr: overrideExpr,
							args: fun.args.copy()
						};

						var overrideField:Field = {
							name: f.name,
							access: f.access.copy(),
							kind: FFun(func),
							pos: Context.currentPos(),
							doc: f.doc,
							meta: f.meta.copy()
						};

						if (!overrideField.access.contains(AOverride))
							overrideField.access.push(AOverride);

						var superField:Field = {
							name: '$FUNC_PREFIX${f.name}',
							pos: Context.currentPos(),
							kind: FFun({
								ret: fun.ret,
								params: fun.params.copy(),
								expr: superFuncExpr,
								args: fun.args.copy()
							}),
							access: f.access.copy()
						};
						if (superField.access.contains(AOverride))
							superField.access.remove(AOverride);
						shadowClass.fields.push(overrideField);
						shadowClass.fields.push(superField);
					default:
						// fuck off >:(

				}
			}

			shadowClass.kind = TDClass({
				pack: cl.pack.copy(),
				name: cl.name
			}, [], false, true, false);
			shadowClass.name = '${cl.name}$CLASS_SUFFIX';
			shadowClass.meta = [{
				name: ':dox',
				pos: Context.currentPos(),
				params: [
					{
						expr: EConst(CIdent("hide")),
						pos: Context.currentPos()
					}
				]
			}];
			var imports = Context.getLocalImports().copy();
			var module = Context.getModule(Context.getLocalModule());
			for(t in module) {
				switch(t) {
					case TInst(t, params):
						if (t != null) {
							var e = t.get();
							processModule(shadowClass, e.module, e.name);
							processImport(imports, e.module, e.name);
						}
					case TEnum(t, params):
						if (t != null) {
							var e = t.get();
							processModule(shadowClass, e.module, e.name);
							processImport(imports, e.module, e.name);
						}
					case TType(t, params):
						if (t != null) {
							var e = t.get();
							processModule(shadowClass, e.module, e.name);
							processImport(imports, e.module, e.name);
						}
					case TAbstract(t, params):
						if (t != null) {
							var e = t.get();
							processModule(shadowClass, e.module, e.name);
							processImport(imports, e.module, e.name);
						}
					default:
						// not needed?
				}
			}

			// var p = new Printer();
			// trace(p.printTypeDefinition(shadowClass));

			shadowClass.fields.push({
				name: "__interp",
				pos: Context.currentPos(),
				kind: FVar(TPath({
					pack: ['hscript'],
					name: 'Interp'
				}))
			});

			var t:ClassType;
			Context.defineModule(cl.module + CLASS_SUFFIX, [shadowClass], imports);
		}

		return fields;
	}

	public static function processModule(shadowClass:TypeDefinition, module:String, n:String) {
		if (n.endsWith("_Impl_"))
			n = n.substr(0, n.length - 6);
		if (module.endsWith("_Impl_"))
			module = module.substr(0, module.length - 6);
		
		shadowClass.meta.push(
			{
				name: ':access',
				params: [
					Context.parse(fixModuleName(module.endsWith('.${n}') ? module : '${module}.${n}'), Context.currentPos())
				],
				pos: Context.currentPos()
			}
		);
	}

	public static function fixModuleName(name:String) {
		return [for(s in name.split(".")) if (s.charAt(0) == "_") s.substr(1) else s].join(".");
	}
	public static function processImport(imports:Array<ImportExpr>, module:String, n:String) {
		if (n.endsWith("_Impl_"))
			n = n.substr(0, n.length - 6);
		module = fixModuleName(module);
		if (module.endsWith("_Impl_"))
			module = module.substr(0, module.length - 6);
		
		imports.push({
			path: [for(m in module.split(".")) {
				name: m,
				pos: Context.currentPos()
			}],
			mode: INormal
		});
	}
	
	public static function cleanExpr(expr:Expr, oldFunc:String, newFunc:String) {
		if (expr == null) return;
		if (expr.expr == null) return;
		switch(expr.expr) {
			case EConst(c):
				switch(c) {
					case CIdent(s):
						if (s == oldFunc)
							expr.expr = EConst(CIdent(newFunc));
					case CString(s, b):
						if (s == oldFunc)
							expr.expr = EConst(CString(s, b));
					default:
						// nothing
				}
			case EField(e, field):
				if (field == oldFunc && e != null) {
					switch(e.expr) {
						case EConst(c):
							switch(c) {
								case CIdent(s):
									if (s == "super")
										expr.expr = EField(e, newFunc);
								default:

							}
						default:

					}
				}
			case EParenthesis(e):
				cleanExpr(e, oldFunc, newFunc);
			case EObjectDecl(fields):
				for(f in fields) {
					cleanExpr(f.expr, oldFunc, newFunc);
				}
			case EArrayDecl(values):
				for(a in values) {
					cleanExpr(a, oldFunc, newFunc);
				}
			case ECall(e, params):
				cleanExpr(e, oldFunc, newFunc);
			case EBlock(exprs):
				for(e in exprs)
					cleanExpr(e, oldFunc, newFunc);
			case EFor(it, expr):
				cleanExpr(it, oldFunc, newFunc);
				cleanExpr(expr, oldFunc, newFunc);
			case EIf(econd, eif, eelse):
				cleanExpr(econd, oldFunc, newFunc);
				cleanExpr(eif, oldFunc, newFunc);
				cleanExpr(eelse, oldFunc, newFunc);
			case EWhile(econd, e, normalWhile):
				cleanExpr(econd, oldFunc, newFunc);
				cleanExpr(e, oldFunc, newFunc);
			case ECast(e, t):
				cleanExpr(e, oldFunc, newFunc);
			case ECheckType(e, t):
				cleanExpr(e, oldFunc, newFunc);
			case ETry(e, catches):
				cleanExpr(e, oldFunc, newFunc);
				for(c in catches) {
					cleanExpr(c.expr, oldFunc, newFunc);
				}
			case EThrow(e):
				cleanExpr(e, oldFunc, newFunc);
			case ETernary(econd, eif, eelse):
				cleanExpr(econd, oldFunc, newFunc);
				cleanExpr(eif, oldFunc, newFunc);
				cleanExpr(eelse, oldFunc, newFunc);
			case ESwitch(e, cases, edef):
				cleanExpr(e, oldFunc, newFunc);
				for(c in cases) {
					cleanExpr(c.expr, oldFunc, newFunc);
				}
				cleanExpr(edef, oldFunc, newFunc);
			case EReturn(e):
				cleanExpr(e, oldFunc, newFunc);
			case EIs(e, t):
				cleanExpr(e, oldFunc, newFunc);
			case EVars(vars):
				for(v in vars) {
					cleanExpr(v.expr, oldFunc, newFunc);
				}
			case ENew(t, params):
				for(p in params) {
					cleanExpr(p, oldFunc, newFunc);
				}
			default:
		}
	}
}
#else
class ClassExtendMacro {
	public var usedClass:Class<Dynamic>;
	public var className:String;
}
#end