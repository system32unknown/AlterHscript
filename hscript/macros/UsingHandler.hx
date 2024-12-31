package hscript.macros;

#if macro
import Type.ValueType;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;
import haxe.macro.Compiler;

using StringTools;

class UsingHandler {
	public static function init() {
		#if !display
		if(Context.defined("display")) return;
		for(apply in Config.ALLOWED_ABSTRACT_AND_ENUM) {
			Compiler.addGlobalMetadata(apply, '@:build(hscript.macros.UsingHandler.build())');
		}
		#end
	}

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var clRef = Context.getLocalClass();
		if (clRef == null) return fields;
		var cl = clRef.get();

		if (cl.name.endsWith("_Impl_") && cl.params.length <= 0 && !cl.meta.has(":multiType") && !cl.name.contains("_HSC")) {
			var metas = cl.meta.get();

			var trimEnum = cl.name.substr(0, cl.name.length - 6);

			var key = cl.module;
			var fkey = key + "." + trimEnum;
			if(key.contains("_")) return fields; // Weird issue, sorry
			switch (key) {
				case "lime.system.Locale" // Error: Unknown identifier : currentLocale, Due to Func
					| "cpp.Function" // Error: Unknown identifier : nativeGetProcAddress, Due to Func
					| "haxe.ds.Vector" // Error: haxe.ds._Vector.VectorData<blit.T> has no field blit, Due to Func
					| "haxe.display.Display" // Error: haxe.display.DisplayItemKind<haxe.display.DisplayLiteral<Dynamic>> has no field Null, Due to Func
					| "cpp.Callable" // Error: cpp.Function.fromStaticFunction must be called on static function, Due to Func
					| "haxe.display.JsonAnonStatusKind" // Error: cannot initialize a variable of type 'char *' with an rvalue of type 'const char *', Due to Func
					| "cpp.CharStar": // Error: cannot initialize a variable of type 'char *' with an rvalue of type 'const char *', Due to Func
						return fields;
			}
			if(Config.DISALLOW_ABSTRACT_AND_ENUM.contains(key) || Config.DISALLOW_ABSTRACT_AND_ENUM.contains(fkey)) return fields;

			var shadowClass = macro class { };
			shadowClass.kind = TDClass();
			shadowClass.params = switch(cl.params.length) {
				case 0: null;
				default: [for (k => e in cl.params) {name: e.name}];
			}
			shadowClass.name = '${cl.name.substr(0, cl.name.length - 6)}_HSC';

			var imports = Context.getLocalImports().copy();
			Utils.setupMetas(shadowClass, imports);

			for(f in fields)
				switch(f.kind) {
					case FFun(fun):
						if (f.access.contains(AStatic)) {
							if (fun.expr != null) {
								fun.expr = macro @:privateAccess $e{fun.expr};
								shadowClass.fields.push(f);
							}
						}
					case FProp(get, set, t, e):
						if (get == "default" && (set == "never" || set == "null")) {
							shadowClass.fields.push(f);
						}
					case FVar(t, e):
						if (f.access.contains(AStatic) || cl.meta.has(":enum") || f.name.toUpperCase() == f.name) {
							var name:String = f.name;
							var enumType:String = cl.name;
							var pack = cl.module.split(".");

							if(pack[pack.length - 1] == trimEnum)
								pack.pop();

							var complexType:ComplexType = t;
							if(complexType == null && e != null) {
								complexType = switch(e.expr) {
									case EConst(CRegexp(_)): TPath({ name: "EReg", pack: [] });
									default: null;
								}
							}
							if(complexType == null) {
								complexType = TPath({
									name: trimEnum,
									pack: [],//pack
								});
							}

							var code = Context.parse('@:privateAccess ($trimEnum.$name)', f.pos); // '${pack.join(".")}.${trimEnum}.$name'

							var field:Field = {
								pos: f.pos,
								name: f.name,
								meta: f.meta,
								kind: FVar(null, code),
								doc: f.doc,
								access: [APublic, AStatic]
							}

							shadowClass.fields.push(field);
						}
					default:
				}
			Context.defineModule(cl.module, [shadowClass], imports);
		}

		return fields;
	}
}
#end