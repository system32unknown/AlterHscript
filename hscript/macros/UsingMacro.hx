package hscript.macros;

#if macro
import Type.ValueType;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;

using Lambda;
using StringTools;
using haxe.macro.Tools;

/**
 * Macro used for the `using Class;` keyword
 * 
 * you can make classes be able to be used specifing the class/classes on Config.hx!
 * ```haxe
 * public static final ALLOWED_USING = ["my.pack.VeryNiceTools"];
 * ```
 * 
 * Usage:
 * 
 * ```haxe
 * // @:usableEntry() // optional
 * // @:usableEntry(forceAny) // optional // forces the class to be called with any type
 * // @:usableEntry(onlyBasic) // optional // only basic types will be allowed
 * // @:usableEntry(onlyBasic, forceAny) // optional // only basic types will be allowed, and the class will be called with any type
 * class VeryNiceTools {}
 * ```
 * 
 * @author NeeEoo
 * @see https://github.com/pisayesiwsi/hscript-iris/blob/master/crowplexus/iris/macro/UsingMacro.macro.hx
**/
class UsingMacro {
	public static inline final USING_PREFIX = "_HX_USING__";

	public static var unallowedMetas:Array<String> = [":noUsing", ":noUse"];

	public static function init() {
		#if !display
		if(Context.defined("display")) return;
		for(apply in Config.ALLOWED_USING) {
			Compiler.addGlobalMetadata(apply, "@:build(hscript.macros.UsingMacro.build())");
		}
		#end
	}

	public static function build() {
		var cls:haxe.macro.Type.ClassType = Context.getLocalClass().get();
		var fields = Context.getBuildFields();

		var packName = (cls.pack.length > 0 ? cls.pack.join(".") + "." : "") + cls.name;

		var alreadyProcessed_metadata = cls.meta.get().find(function(m) return m.name == ':usingProcessed');
		if (alreadyProcessed_metadata != null)
			return fields;

		var entryField = cls.meta.get().find(function(m) return m.name == ':usableEntry');
		var hasParams = entryField != null && entryField.params != null;
		var forceAny = false;
		var onlyBasic = false;
		if (hasParams) {
			for (i in 0...entryField.params.length) {
				if (entryField.params[i].expr.match(EConst(CIdent("onlyBasic"))))
					onlyBasic = true;
				if (entryField.params[i].expr.match(EConst(CIdent("forceAny"))))
					forceAny = true;
			}
		}

		var data: Array<Array<String>> = [];

		for (field in fields) {
			// functions marked with @:noUsing won't be able to be used by variables
			// also if you want it to be usable in source, but not in the script, use @:noUse
			for(m in field.meta) 
				if(unallowedMetas.contains(m.name))
					continue;

			if(!field.access.contains(AStatic))
				continue;

			switch (field.kind) {
				default:
				case FFun(f):
					if (f.args.length == 0)
						continue;
					var arg = f.args[0];
					if (arg.type == null)
						continue;
					var type = arg.type;

					var valueType: String = switch (type) {
						case TPath({name: "Int", pack: []}):
							"TInt";
						case TPath({name: "Float", pack: []}):
							"TFloat";
						case TPath({name: "Single", pack: []}):
							"TFloat";
						case TPath({name: "String", pack: []}):
							"TClass(String)";
						case TPath({name: "Bool", pack: []}):
							"TBool";
						case TPath({name: "Array", pack: []}):
							"TClass(Array)";
						case TPath({name: "Map", pack: []}):
							"TClass(haxe.Constraints.IMap)";
						case TPath({name: "Dynamic", pack: []}):
							null;
						case TPath({name: "Class", pack: []}):
							"TClass(null)"; // this feels wrong
						case TPath({name: "Enum", pack: []}):
							"TEnum(null)";
						case TPath({name: "Null", pack: []}):
							"TUnknown";
						default:
							null; // null acts as a wildcard
					}

					// MIGHT CRASH COMPILATION?
					if (!onlyBasic && valueType == null) {
						var rtype = type.toType();

						switch (rtype) {
							case TInst(t, []):
								valueType = "TClass(" + t.toString() + ")";
							default:
						}
					}

					if (forceAny) {
						valueType = null;
					}

					data.push([field.name, valueType]);
			}
		}

		if(data.length == 0)
			return fields;

		fields.push({
			name: '$USING_PREFIX${packName.replace(".", "_")}',
			access: [APrivate, AStatic],
			kind: FVar(macro : Map<String, Type.ValueType>, {
				var arr: Array<Expr> = [];
				for (i in data)
					if (i[1] != null)
						arr.push(macro $v{i[0]} => ${Context.parse("Type.ValueType." + i[1], Context.currentPos())});
					else
						arr.push(macro $v{i[0]} => null);
				macro $a{arr};
			}),
			pos: cls.pos,
		});

		cls.meta.add(':usingProcessed', [], cls.pos);

		return fields;
	}
}
#end