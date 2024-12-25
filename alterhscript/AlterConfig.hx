package alterhscript;

abstract OneOfTwo<T1, T2>(Dynamic) from T1 from T2 to T1 to T2 {}

typedef RawAlterConfig = {
	var name:String;
	var ?autoRun:Bool;
	var ?autoPreset:Bool;
	var ?localBlocklist:Array<String>;
};

typedef AutoAlterConfig = OneOfTwo<AlterConfig, RawAlterConfig>;

class AlterConfig {
	public var name:String = null;
	public var autoRun:Bool = true;
	public var autoPreset:Bool = true;
	public var packageName:String = null;
	@:unreflective public var localBlocklist:Array<String> = [];

	/**
	 * Initialises the Alter script config.
	 *
	 * @param name			The obvious!
	 * @param autoRun					Makes the script run automatically upon being created.
	 * @param localBlocklist	List of classes or enums that cannot be used within this particular script
	**/
	public function new(name:String, autoRun:Bool = true, autoPreset:Bool = true, ?localBlocklist:Array<String>) {
		this.name = name;
		this.autoRun = autoRun;
		this.autoPreset = autoPreset;
		if (localBlocklist != null) this.localBlocklist = localBlocklist;
	}

	public static function from(d:AutoAlterConfig):AlterConfig {
		if (d != null && Std.isOfType(d, AlterConfig)) return d;
		var d:RawAlterConfig = cast d;
		return new AlterConfig(d.name, d.autoRun, d.autoPreset, d.localBlocklist);
	}
}