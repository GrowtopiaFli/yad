package cli;

import sys.thread.Thread;
import sys.thread.EventLoop;
import sys.FileSystem;
import haxe.io.Path;

class ConState
{	
	public var echo:Bool = false;
	public var stopOnKey:Bool = false;

	public var updateLoop:EventLoop;
	public var onKeyLoop:EventLoop;
	public var updateHnd:EventHandler;
	public var onKeyHnd:EventHandler;
	
	public function new() {}
	function update(elapsed:Float):Void {}
	function onKey(char:Int, key:String):Void {}
	
	public function create():Void
	{
		var dt:Float = ConHnd.deltaTime;
		var dtMs:Int = Math.floor(dt * 1000);
		onKeyLoop = new EventLoop();
		onKeyHnd = onKeyLoop.repeat(function()
		{
			if (stopOnKey) return;
			var char:Int = Sys.getChar(echo);
			onKey(char, String.fromCharCode(char));
		}, dtMs);
		updateLoop = new EventLoop();
		updateHnd = updateLoop.repeat(function()
		{
			update(dt);
		}, dtMs);
		Thread.createWithEventLoop(function()
		{
			onKeyLoop.loop();
		});
		updateLoop.loop();
	}
	
	public function terminate():Void
	{
		onKeyLoop.cancel(onKeyHnd);
		updateLoop.cancel(updateHnd);
	}
}