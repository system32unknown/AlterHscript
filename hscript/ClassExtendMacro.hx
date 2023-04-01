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

	public static var applyOn:Array<String> = ["flixel", "funkin"];

	public function new(className:String, usedClass:Class<Dynamic>) {
		this.className = className;
		this.usedClass = usedClass;
	}

	public static function init() {
		Compiler.addGlobalMetadata('flixel', '@:build(hscript.ClassExtendMacro.build())');
		trace("TEST");
	}

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var clRef = Context.getLocalClass();
		if (clRef == null) return fields;
		var cl = clRef.get();

		if (cl.isAbstract || cl.isExtern || cl.isFinal || cl.isInterface) return fields;
		if (!cl.name.endsWith("_Impl_") && !cl.name.endsWith(CLASS_SUFFIX) && !cl.name.endsWith("__Softcoded")) {//(/* cl.name.startsWith("Flx") && */ cl.name.endsWith("_Impl_") && cl.params.length <= 0 && !cl.meta.has(":multiType")) {
			var metas = cl.meta.get();

			var hasInterp = false;
			if(cl.params.length > 0) {
				return fields;
			} else if (cl.superClass != null) {
				var sClass = cl;
				var inModifiedModule = false;
				while(sClass != null) {
					if (sClass.superClass != null) {
						if (sClass.superClass.params != null && sClass.superClass.params.length > 0)
							return fields;
						if (!inModifiedModule)
							for(e in applyOn)
								if (sClass.superClass.t.get().module.startsWith(e)) {
									inModifiedModule = true;
									hasInterp = true;
									break;
								}
					}

					if (!hasInterp)
						for(f in sClass.fields.get())
							if (f.name == "__interp") {
								hasInterp = true;
								break;
							}
					sClass = sClass.superClass != null ? sClass.superClass.t.get() : null;
					
				}
				if (sClass != null)
					return fields;
			}

			for(f in fields.copy()) {
				if (f.name == "new")
					continue;
				if (f.name.startsWith(FUNC_PREFIX))
					continue;
				if (f.access.contains(ADynamic) || f.access.contains(AStatic) || f.access.contains(AExtern) || f.access.contains(AInline))
					continue;

				switch(f.kind) {
					case FFun(fun):
						var expr = fun.expr;
						var newExpr = fun.ret.match(TPath({name: "Void"})) ? (macro {
							var name = ${{
								pos: Context.currentPos(),
								expr: EConst(CString(f.name, DoubleQuotes))
							}};
							var v:Dynamic;
							if (__interp != null && (v = __interp.resolve(name, false)) != null && Reflect.isFunction(v)) {
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
							}
							else {
								${{
									expr: ECall({
										pos: Context.currentPos(),
										expr: EConst(CIdent('$FUNC_PREFIX${f.name}'))
									}, fun.args != null ? [for(a in fun.args) {
										pos: Context.currentPos(),
										expr: EConst(CIdent(a.name))
									}] : []),
									pos: Context.currentPos()
								}}
							}
						}) : (macro {
							var name = ${{
								pos: Context.currentPos(),
								expr: EConst(CString(f.name, DoubleQuotes))
							}};
							var v:Dynamic;
							if (__interp != null && (v = __interp.resolve(name, false)) != null && Reflect.isFunction(v)) {
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
							else {
								return ${{
									expr: ECall({
										pos: Context.currentPos(),
										expr: EConst(CIdent('$FUNC_PREFIX${f.name}'))
									}, fun.args != null ? [for(a in fun.args) {
										pos: Context.currentPos(),
										expr: EConst(CIdent(a.name))
									}] : []),
									pos: Context.currentPos()
								}}
							}
						});
						fun.expr = newExpr;

						if (f.access.contains(AOverride) && hasInterp)
							cleanExpr(expr, f.name, '$FUNC_PREFIX${f.name}');	

						var newFunc:Function = {
							args: fun.args,
							ret: fun.ret,
							params: fun.params,
							expr: macro {
								@:privateAccess
								${expr}
							}
						};

						fields.push({
							name: '$FUNC_PREFIX${f.name}',
							pos: f.pos,
							kind: FFun(newFunc),
							access: f.access.copy()
						});

						if (!hasInterp)
							fields[fields.length - 1].access.remove(AOverride);
					default:
						// fuck off >:(

				}
			}

			if (!hasInterp) {
				fields.push({
					name: "__interp",
					pos: Context.currentPos(),
					kind: FVar(TPath({
						pack: ['hscript'],
						name: 'Interp'
					}))
				});
			}
		}

		return fields;
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