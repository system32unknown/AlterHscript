# FEATURES

- Custom Classes
  - Final Classes
  - Static Classes
  - Allow for type check (`is`)
  - Allow extending other custom classes
- Enums

  ```haxe
  enum TypeValue {
    NUMBER(n:Int);
    DECIMAL(d:Float, ?p:Int);
    CHARACTER(s:String);
    BOOLEAN(b:Bool);
  }

  var type = TypeValue.DECIMAL(10.1234, 2);
  // You need to type the full enum field for each case
  // i.e. you can't type the enum field directly (limitation for now)
  switch(type) {
    case TypeValue.NUMBER(number): 
      trace("number: " + number);
    case TypeValue.DECIMAL(decimal, precision): 
      if(precision != null)
        trace("decimal: " + decimal + " | rounded decimal: " + roundDecimal(decimal, precision));
      else
        trace("decimal: " + decimal);
    case TypeValue.CHARACTER(char): 
      trace("character: " + char);
    default: 
      trace("unknown type");
  }

  function roundDecimal(Value:Float, Precision:Int) {
    var mult:Float = Math.pow(10, Precision);
    return Math.fround(Value * mult) / mult;
  }
  ```

  - Enum matching with arguments for switch statements (for real and scripted enums)
- Property Fields (`(get, set)` variables)

  ```haxe
  public var myvar(get, set):Int;
  var _myvar:Int = 10;

  function get_myvar():Int {
    return _myvar;
  }

  function set_myvar(val:Int):Int {
    if(val > 10) return _myvar = val;
    return val;
  }
  ```

  - `@:isVar` metadata support
  
- Static extension (`using`)

  ```haxe
  using StringTools;

  class IntExtender {
    static public function triple(i:Int) {
      return i * 3;
    }
  }

  // need to create/import the custom class
  // before setting the extension (limitation for now)
  using IntExtender;

  var str = "  Hello World!  ";
  trace(str.trim()); // "Hello World!"
  trace(12.triple()); // 36
  ```

  - Support for real and custom classes
- Misc.
  - Allow using type parameters for creating objects (i.e. `var a = new TypedObject<Int>();`)
  - Allow `package` declaration. Ignored by the interpreter.
