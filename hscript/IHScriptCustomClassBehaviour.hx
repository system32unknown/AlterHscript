package hscript;

interface IHScriptCustomClassBehaviour extends IHScriptCustomAccessBehaviour{
	public var __interp:Interp;
	public var __real_fields:Array<String>;
	public var __class__fields:Array<String>;

}