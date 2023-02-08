package cli;

import haxe.MainLoop;

class ConHnd
{
	private static var curState:ConState;
	public static var deltaTime:Float;
	
	public static function init(dt:Float, initState:Class<ConState>, ?stateArgs:Array<Dynamic>):Void
	{
		if (stateArgs == null) stateArgs = [];
		deltaTime = dt;
		curState = Type.createInstance(initState, stateArgs);
		runState();
	}
	
	public static function switchState(newState:Class<ConState>, ?stateArgs:Array<Dynamic>):Void
	{
		if (curState != null) curState.terminate();
		if (stateArgs == null) stateArgs = [];
		curState = Type.createInstance(newState, stateArgs);
		runState();
	}
	
	public static function runState():Void
	{
		MainLoop.runInMainThread(curState.create);
	}
}