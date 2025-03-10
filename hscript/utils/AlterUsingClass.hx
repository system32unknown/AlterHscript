package hscript.utils;

/**
 * This is used to mark classes that can be used with the `using` keyword.
 * You can also add @:alterUsableEntry to your class.
 * If you wanna force the class to be called with any type, you can add @:alterUsableEntry(forceAny)
**/
@:autoBuild(hscript.macros.UsingMacro.build())
interface UsingClass {}