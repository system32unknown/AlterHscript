package hscript.macros;

#if macro
import haxe.macro.Type.MetaAccess;
import haxe.macro.Type.FieldKind;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.VarAccess;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.*;
import Sys;

using StringTools;

class ClassExtendMacro {
	static inline final FUNC_PREFIX:String = "_HX_SUPER__";
	static inline final CLASS_SUFFIX:String = "_HSX";

	static final unallowedMetas:Array<String> = [":bitmap", ":noCustomClass", ":generic"];

	/**
	 * List of classes which are known not to be invalid.
	 */
	static final unallowedClasses:Array<String> = [
		"sys.thread.FixedThreadPool", // Error: Type name sys.thread.Worker_HSX is redefined from module sys.thread.FixedThreadPool
		"sys.thread.EventLoop", // Error: cant override force inlined
		"StdTypes", // Error: Cant extend basic class
		"Date",     // Error: Cant extend basic class
		"Xml",      // Error: Cant extend basic class
		"hscript.CustomClassHandler.TemplateClass", // Error: Redefined
		"hscript.CustomClassHandler.CustomTemplateClass", // Error: Redefined
	];

	public static function init():Void {
		#if !display
		#if CUSTOM_CLASSES
		for (apply in Config.ALLOWED_CUSTOM_CLASSES) {
			Compiler.addGlobalMetadata(apply, "@:build(hscript.macros.ClassExtendMacro.build())");
		}
		#end
		#end
	}

	public static function build():Array<Field> {
		var fields:Array<Field> = Context.getBuildFields();
		var clRef = Context.getLocalClass();
		if (clRef == null) return fields;

		var cl:ClassType = clRef.get();
		if (cl.isAbstract || cl.isExtern || cl.isFinal || cl.isInterface) return fields;
		if (cl.name.endsWith("_Impl_") || cl.name.endsWith(CLASS_SUFFIX) || cl.name.endsWith("_HSC")) return fields;
		if (cl.module.contains("_")) return fields; // Weird issue, sorry
		if (cl.params.length > 0) return fields;

		var key = cl.module;
		var fkey = cl.module + "." + cl.name;

		if (unallowedClasses.contains(key) || unallowedClasses.contains(fkey)) return fields;
		if (Config.DISALLOW_CUSTOM_CLASSES.contains(cl.module) || Config.DISALLOW_CUSTOM_CLASSES.contains(fkey)) return fields;

		var metas = cl.meta.get();

		for (m in metas)
			if (unallowedMetas.contains(m.name))
				return fields;
		
		var shadowClass = macro class {};

		var definedFields:Array<String> = [];
		var hasConstructor:Bool = false;
		var hasHgetInSuper:Bool = false;
		var hasHsetInSuper:Bool = false;

		for (f in fields.copy()) {
			if (f.name == "new") {
				hasConstructor = true;
				continue;
			}
			if (f.name == "hget") {
				hasHgetInSuper = true;
				continue;
			}
			if (f.name == "hset") {
				hasHsetInSuper = true;
				continue;
			}

			if (f.name.startsWith(FUNC_PREFIX)) continue;
			if (definedFields.contains(f.name)) continue; // no duplicate fields

			if (f.access.contains(ADynamic) || f.access.contains(AStatic) || f.access.contains(AExtern) || f.access.contains(AInline) || f.access.contains(AFinal))
				continue;

			for (m in f.meta)
				if (unallowedMetas.contains(m.name))
					continue;

			switch (f.kind) {
				case FFun(fun):
					if (fun == null) continue;
					// TODO: Support for this maybe?
					if (fun.params != null && fun.params.length > 0) continue;

					var overrideExpr:Expr;
					var returns:Bool = !fun.ret.match(TPath({name: "Void"}));

					var name:String = f.name;
					var arguments = fun.args == null ? [] : [for(a in fun.args) macro $i{a.name}];

					if (returns) {
						overrideExpr = macro {
							var name:String = $v{name};

							if (__custom__variables != null) {
								if (__custom__variables.exists(name)) {
									var v:Dynamic = null;
									if (Reflect.isFunction(v = __custom__variables.get(name))) {
										return v($a{arguments});
									}
								}
							}
							return super.$name($a{arguments});
						};
					}
					else {
						overrideExpr = macro {
							var name:String = $v{name};

							if (__custom__variables != null) {
								if (__custom__variables.exists(name)) {
									var v:Dynamic = null;
									if (Reflect.isFunction(v = __custom__variables.get(name))) {
										v($a{arguments});
										return;
									}
								}
							}
							super.$name($a{arguments});
						};
					}

					var superFuncExpr:Expr = returns ? {
						macro return super.$name($a{arguments});
					} : {
						macro super.$name($a{arguments});
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
					definedFields.push(f.name);

				default:
			}
		}

		if (definedFields.length == 0 && !hasConstructor) return fields;

		shadowClass.kind = TDClass({
			pack: cl.pack.copy(),
			name: cl.name
		}, [
			{name: "IHScriptCustomAccessBehaviour", pack: ["hscript"]},
			{name: "IHScriptCustomClassBehaviour", pack: ["hscript"]}
		], false, true, false);
		shadowClass.name = '${cl.name}$CLASS_SUFFIX';

		var imports = Context.getLocalImports().copy();
		Utils.setupMetas(shadowClass, imports);
		Utils.processImport(imports, "hscript.UnsafeReflect", "UnsafeReflect");

		// Adding hscript getters and setters

		shadowClass.fields.push({
			name: "__interp",
			pos: Context.currentPos(),
			kind: FVar(macro: hscript.Interp),
			access: [APublic]
		});

		shadowClass.fields.push({
			name: "__custom__variables",
			pos: Context.currentPos(),
			kind: FVar(macro: Map<String, Dynamic>),
			access: [APublic]
		});

		shadowClass.fields.push({
			name: "__allowSetGet",
			pos: Context.currentPos(),
			kind: FVar(macro: Bool, macro true),
			access: [APublic]
		});

		shadowClass.fields.push({
			name: "__real_fields",
			pos: Context.currentPos(),
			kind: FVar(macro: Array<String>),
			access: [APublic]
		});

		shadowClass.fields.push({
			name: "__class__fields",
			pos: Context.currentPos(),
			kind: FVar(macro: Array<String>),
			access: [APublic]
		});

		shadowClass.fields.push({
			name: "__callGetter",
			pos: Context.currentPos(),
			kind: FFun({
				ret: macro: Dynamic,
				params: [],
				expr: macro {
					__allowSetGet = false;
					var v = __custom__variables.get("get_" + name)();
					__allowSetGet = true;
					return v;
				},
				args: [
					{
						name: "name",
						opt: false,
						meta: [],
						type: macro: String
					}
				]
			}),
			access: [APublic]
		});

		shadowClass.fields.push({
			name: "__callSetter",
			pos: Context.currentPos(),
			kind: FFun({
				ret: macro: Dynamic,
				params: [],
				expr: macro {
					__allowSetGet = false;
					var v = __custom__variables.get("set_" + name)(val);
					__allowSetGet = true;
					return v;
				},
				args: [
					{
						name: "name",
						opt: false,
						meta: [],
						type: macro: String
					},
					{
						name: "val",
						opt: false,
						meta: [],
						type: macro: Dynamic
					}
				]
			}),
			access: [APublic]
		});

		var hgetField = if (hasHgetInSuper) {
			macro {
				if (__allowSetGet && __custom__variables.exists("get_" + name))
					return __callGetter(name);
				if (__custom__variables.exists(name))
					return __custom__variables.get(name);
				return super.hget(name);
			}
		}
		else {
			macro {
				if (__allowSetGet && __custom__variables.exists("get_" + name))
					return __callGetter(name);
				if (__custom__variables.exists(name))
					return __custom__variables.get(name);
				return UnsafeReflect.getProperty(this, name);
			}
		}

		var hsetField = if (hasHsetInSuper) {
			macro {
				if (__allowSetGet && __custom__variables.exists("set_" + name))
					return __callSetter(name, val);
				if (__custom__variables.exists(name)) {
					__custom__variables.set(name, val);
					return val;
				}
				if (__real_fields.contains(name)) {
					UnsafeReflect.setProperty(this, name, val);
					return UnsafeReflect.field(this, name);
				}
				return super.hset(name, val);
			}
		}
		else {
			macro {
				if (__allowSetGet && __custom__variables.exists("set_" + name))
					return __callSetter(name, val);
				if (__custom__variables.exists(name)) {
					__custom__variables.set(name, val);
					return val;
				}
				if (__real_fields.contains(name)) {
					UnsafeReflect.setProperty(this, name, val);
					return UnsafeReflect.field(this, name);
				}
				__custom__variables.set(name, val);
				return val;
			}
		}

		shadowClass.fields.push({
			name: "hset",
			pos: Context.currentPos(),
			access: hasHsetInSuper ? [AOverride, APublic] : [APublic],
			kind: FFun({
				ret: macro: Dynamic,
				params: [],
				expr: hsetField,
				args: [
					{
						name: "name",
						opt: false,
						meta: [],
						type: macro: String
					},
					{
						name: "val",
						opt: false,
						meta: [],
						type: macro: Dynamic
					}
				]
			})
		});

		shadowClass.fields.push({
			name: "hget",
			pos: Context.currentPos(),
			access: hasHgetInSuper ? [AOverride, APublic] : [APublic],
			kind: FFun({
				ret: macro: Dynamic,
				params: [],
				expr: hgetField,
				args: [
					{
						name: "name",
						opt: false,
						meta: [],
						type: macro: String
					}
				]
			})
		});

		Context.defineModule(cl.module, [shadowClass], imports);
		return fields;
	}
}
#else
class ClassExtendMacro {}
#end