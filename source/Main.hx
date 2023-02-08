package;

import cli.*;

import sys.FileSystem;

import haxe.io.Path;

using StringTools;

class Main
{
	public static var instance:Main;
	
	public static var osList:Array<String> = ["Windows", "Linux", "Mac"];
	public static var os:Int = osList.indexOf(Sys.systemName());
	public static var cwd:String = new Path(Path.normalize(FileSystem.absolutePath(new Path(Sys.programPath()).dir))) + "/";
	public static var le:String = (osList[os] == "Windows" ? "\r" : "") + "\n";
	
	public static var terminateChars:Array<Int> = [3, 13, 32];
	
	public static var failText:String = "Try again later or recheck your internet, and if the issue still persists then it is sadly not possible to your requested action";
	public static var quitText:String = "Press Enter/Space To Exit This Program...";
	
	public function new() {}
	static function main()
	{
		instance = new Main();
		instance.init();
	}
	
	public var updateRate:Float = 1 / 60;
	
	public function init()
	{
		ConHnd.init(updateRate, Program);
	}
	
	public static function quit():Void
	{
		while (true)
		{
			if (terminateChars.contains(Sys.getChar(false))) Sys.exit(1);
		}
	}
	
	public static function errln(e:String, toQuit:Bool = false):Void
	{
		Sys.print("--------" + le + "[ERROR] : " + e + le + (toQuit ? failText + le + quitText + le : "") + "--------" + le);
	}
	
	public static function error(e:String):Void
	{
		errln(e, true);
		quit();
	}
}