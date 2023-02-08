package;

import Main.*;

import cli.*;

import sys.io.Process;
import sys.io.File;
import sys.FileSystem;

import haxe.Json;
import haxe.Http;
import haxe.io.Bytes;
import haxe.io.Path;

using StringTools;

class Program extends ConState
{	
	public static var vidFile:String = "yad.videos";
	public static var chnlFile:String = "yad.channels";
	public static var binaryUrl:String = "https://raw.githubusercontent.com/GrowtopiaFli/yad-binaries/master";
	
	public var yadIntrTxt:String =
		"YAD Interface - Downloads Archived YT Videos" + le + le +
		"Press One Of The Numbers Below On Your Keyboard To Select An Action:" + le + "   " +
		"1). Download Archived Videos From \"" + vidFile + "\"" + le + "   " +
		"2). Dump Channel Videos From \"" + chnlFile + "\" To \"" + vidFile + "\" (This Won't Remove The Existing Video Links In \"" + vidFile + "\" But It Does Remove Comments)" + le;
	
	public var ytDlpPath:String = ["./yt-dlp.exe", "./yt-dlp", "thisdoesnotmatteranyway"][os];
	public var aria2Path:String = ["./aria2c.exe", "./aria2", "thisalsodoesnotmatter"][os];
	
	public var ytDlpUrl:String = Path.join([binaryUrl, ["yt-dlp" + #if(HXCPP_M32) "_x86" #else "" #end + ".exe", "yt-dlp_linux", "nosupportforthis"][os]]);
	public var aria2Url:String = Path.join([binaryUrl, ["aria2c" + #if(HXCPP_M32) "_x86" #else "" #end + ".exe", "aria2c", "nosupportforthis;-;"][os]]);
	
	public var timemapUrl:String = "https://web.archive.org/web/timemap/link";
	public var youtubeUrl:String = "https://www.youtube.com";
	public var youtubePath:String = "videos";
	
	public var ytDlpConf:String = "./yt-dlp.conf";
	
	public var allowedChnlLnks:Array<String> = [
		"@",
		"channel/",
		"c/",
		"user/"
	];
	
	public var vidFileData:String;
	public var chnlFileData:String;
	
	public var commentChars:Array<String> = ["-", "//"];
	
	public var vfdLines:Array<Array<String>>;
	public var cfdLines:Array<String>;
	public var webArchiveList:Array<String>;
	
	public var yadInit:Bool = false;
	public var requestingArchive:Bool = false;
	public var time:Float = 0;
	public var origFormat:Bool = false;
	
	public var queueDownload:String;
	public var downloaderProcess:Process;
	public var strings:Array<String> = [
		"youtube] ",
		"extracting url: ",
		"Extracting URL",
		": ",
		"<",
		">;",
		"ytInitialData = ",
		"window[\"ytInitialData\"] = ",
		"window['ytInitialData'] = ",
		"};",
		"has already been downloaded",
		"100%"
	];
	
	public var optArgs:Array<String> = [];
	
	public var formats:Array<Array<String>> = [];
	
	override public function create():Void
	{
		if (os < 0) error("Unsupported OS!" + le + "Please Use A Valid One");
		Sys.setCwd(cwd);
		initYadIntr();
		
		super.create();
	}

	public function initYadIntr():Void
	{
		Sys.print(yadIntrTxt);
		yadInit = true;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (requestingArchive)
		{
			var prevTime:Int = Std.int(time);
			time += elapsed;
			var curTime:Int = Std.int(time);
			if (curTime > prevTime)
			{
				var whitespaces:String = "";
				for (i in 0...32) whitespaces += " ";
				var timeFormatted:String = Std.int(curTime / 60) + "m " + curTime % 60 + "s";
				Sys.print("\rTime Elapsed: " + timeFormatted + whitespaces);
			}
		}
		else
		{
			time = 0;
		}
	}
	
	override function onKey(char:Int, key:String):Void
	{
		super.onKey(char, key);
		
		if (char == terminateChars[0]) Sys.exit(1);
		
		if (yadInit)
		{
			yadInit = false;
			switch (Std.parseInt(key))
			{
				case 1:
					Sys.print(le);
					parseVidFile();
					if (vidFileData.length == 0) error("Empty \"" + vidFile + "\" File");
					var titles:Array<String> = [];
					for (vidData in vfdLines)
					{
						if (vidData.length != 2) error("\"" + vidFile + "\" Has An Invalid Video Data (Title & Video Id)" + le + "(Make Sure You Had A Title And Video Id On The File Separated Into Two Lines)");
						if (vidData[0].length == 0) error("\"" + vidFile + "\" Has An Invalid Video Title");
						titles.push(vidData[0]);
						if (vidData[1].length != 11) error("\"" + vidFile + "\" Has An Invalid Video Id");
					}
					var vidChoices:String = le + "Type One Of The Numbers Below To Select A Video To Download:" + le;
					for (i in 0...titles.length) vidChoices += "   " + Std.string(i + 1) + "). " + titles[i] + le;
					Sys.print(vidChoices + le);
					queryVid();
				case 2:
					Sys.print(le + "Checking \"" + chnlFile + "\"" + le);
					var exists:Bool = FileSystem.exists(chnlFile);
					if (exists) exists = !FileSystem.isDirectory(chnlFile);
					if (!exists) File.saveContent(chnlFile, "");
					chnlFileData = File.getContent(chnlFile).replace("\r", "").trim();
					cfdLines = chnlFileData.split("\n")
					.map(function(a:String)
						{
							return a.trim();
						})
					.filter(function(a:String)
						{
							return a.length > 0;
						});
					if (chnlFileData.length == 0) error("Empty \"" + chnlFile + "\" File");
					for (chnlData in cfdLines)
					{
						var valid:Bool = false;
						for (chnlLink in allowedChnlLnks)
						{
							if (chnlData.startsWith(chnlLink))
							{
								valid = chnlData.length > chnlLink.length;
								if (!valid) break;
							}
						}
						if (!valid) error("\"" + chnlFile + "\" Has An Unknown Youtube Channel Format");
					}
					parseVidFile();
					var invalid:Bool = false;
					if (vidFileData.length == 0)
					{
						invalid = true;
						Sys.print("Empty \"" + vidFile + "\" File" + le);
					}
					if (!invalid)
					{
						for (vidData in vfdLines)
						{
							if (vidData.length != 2)
							{
								Sys.print("\"" + vidFile + "\" Has An Invalid Video Data (Title & Video Id)" + le + "(Make Sure You Had A Title And Video Id On The File Separated Into Two Lines)" + le);
								break;
							}
							if (vidData[0].length == 0)
							{
								Sys.print("\"" + vidFile + "\" Has An Invalid Video Title" + le);
								break;
							}
							if (vidData[1].length != 11)
							{
								Sys.print("\"" + vidFile + "\" Has An Invalid Video Id" + le);
								break;
							}
						}
					}
					if (invalid) vfdLines = [];
					dumpChannel(0);
				default:
					yadInit = true;
			}
		}
	}
	
	public function parseVidFile():Void
	{
		Sys.print("Checking \"" + vidFile + "\"" + le);
		var exists:Bool = FileSystem.exists(vidFile);
		if (exists) exists = !FileSystem.isDirectory(vidFile);
		if (!exists) File.saveContent(vidFile, "");
		vidFileData = File.getContent(vidFile).replace("\r", "").trim();
		vfdLines = vidFileData.split("\n")
		.filter(function(a:String)
			{
				var keep:Bool = true;
				for (commentChar in commentChars)
				{
					if (a.startsWith(commentChar)) keep = false;
				}
				return keep;
			})
		.join("\n").split("\n\n").map(function(a:String)
			{
				return a.split("\n");
			});
	}
	
	public var retries:Int = 0;
	
	public function dumpChannel(idx:Int):Void
	{
		if (idx >= cfdLines.length)
		{
			Sys.print("Dumping Has Finished!" + le);
			Sys.print(quitText + le);
			quit();
		}
		Sys.print("Retrieving Timemap For \"" + cfdLines[idx] + "\"" + le);
		var timemap:Http = new Http(Path.join([timemapUrl, youtubeUrl, cfdLines[idx], youtubePath]));
		timemap.onError = error;
		timemap.onData = function(data:String)
		{
			webArchiveList = data.replace("\r", "").split("\n")
			.filter(function(a:String)
				{
					return a.contains("web.archive.org/web/20");
				})
			.map(function(a:String)
				{
					return a.substring(a.indexOf(strings[4]) + 1, a.indexOf(strings[5]));
				});
			Sys.print("Retrieving All Archived URLs From The Timemap:" + le + "   " + webArchiveList.join(le + "   ") + le + le);
			dumpChannelArchive(idx, 0);
		}
		timemap.request(false);
	}
	
	public function dumpChannelArchive(cIdx:Int, idx:Int):Void
	{
		if (idx >= webArchiveList.length) return dumpChannel(cIdx + 1);
		Sys.print("Downloading Data From \"" + webArchiveList[idx] + "\"" + le + le);
		var archiveRequest:Http = new Http(webArchiveList[idx]);
		archiveRequest.onError = function(msg:String)
		{
			requestingArchive = false;
			Sys.print(le + le + "Failed To Reach \"" + webArchiveList[idx] + "\"" + le);
			if (retries <= 3)
			{
				retries++;
				Sys.print("Retrying..." + le + le);
				return dumpChannelArchive(cIdx, idx);
			}
			else
			{
				retries = 0;
				Sys.print("Skipping After 3 Failed Attempts..." + le + le);
				return dumpChannelArchive(cIdx, idx);
			}
		}
		archiveRequest.onData = function(data:String)
		{
			requestingArchive = false;
			Sys.print(le + "Finished Download!" + le);
			data = data.replace("\r", "").split("\n")
			.map(function(a:String)
				{
					return a.trim();
				})
			.join("\n");
			var json:Dynamic = {};
			var valid:Bool = false;
			var skippingErr:String = "Skipping \"" + webArchiveList[idx] + "\"" + le + le;
			for (i in 0...3)
			{
				var strSplit:Array<String> = data.split(strings[6 + i]);
				if (strSplit.length < 2) continue;
				try
				{
					json = Json.parse(strSplit[1].substring(0, strSplit[1].indexOf(strings[9]) + 1));
					origFormat = i > 0;
					valid = true;
					break;
				}
				catch (e:Dynamic)
				{
					Sys.print("Cannot Parse Json" + le);
					Sys.print(skippingErr);
					break;
				}
			}
			if (!valid) return dumpChannelArchive(cIdx, idx + 1);
			try
			{
				if (origFormat)
				{
					if (json.contents != null &&
						json.contents.twoColumnBrowseResultsRenderer != null && 
						Std.isOfType(json.contents.twoColumnBrowseResultsRenderer.tabs, Array))
					{
						var contents:Array<Dynamic> = [];
						var tabs:Array<Dynamic> = json.contents.twoColumnBrowseResultsRenderer.tabs;
						for (tab in tabs)
						{
							if (tab.tabRenderer != null &&
								Std.isOfType(tab.tabRenderer.title, String) &&
								tab.tabRenderer.title == "Videos" &&
								tab.tabRenderer.content != null &&
								tab.tabRenderer.content.sectionListRenderer != null &&
								tab.tabRenderer.content.sectionListRenderer.contents != null &&
								Std.isOfType(tab.tabRenderer.content.sectionListRenderer.contents, Array))
							{
								contents = tab.tabRenderer.content.sectionListRenderer.contents;
								break;
							}
						}
						if (contents.length == 0) Sys.print("No Video Data Available On This Archive" + le);
						var iterate:Int = 0;
						for (item in contents)
						{
							if (item.itemSectionRenderer != null &&
								Std.isOfType(item.itemSectionRenderer.contents, Array) &&
								item.itemSectionRenderer.contents[0] != null &&
								item.itemSectionRenderer.contents[0].videoRenderer != null &&
								Std.isOfType(item.itemSectionRenderer.contents[0].videoRenderer.videoId, String) &&
								item.itemSectionRenderer.contents[0].videoRenderer.videoId.length == 11 &&
								item.itemSectionRenderer.contents[0].videoRenderer.title != null &&
								Std.isOfType(item.itemSectionRenderer.contents[0].videoRenderer.title.simpleText, String))
							{
								var videoRenderer:Dynamic = item.itemSectionRenderer.contents[0].videoRenderer;
								var videoData:Array<String> = [videoRenderer.title.simpleText, videoRenderer.videoId];
								Sys.print("   " + videoData[0] + le);
								var contains:Bool = false;
								for (vfd in vfdLines)
								{
									if (vfd[0] == videoData[0] && vfd[1] == videoData[1]) contains = true;
								}
								if (!contains) vfdLines.push(videoData);
							}
							else
							{
								Sys.print("Video Data Item " + iterate + " Invalid" + le);
							}
							iterate++;
						}
					}
					Sys.print("Updating \"" + vidFile + "\"" + le);
					File.saveContent(vidFile, vfdLines
					.map(function(a:Array<String>)
						{
							return a.join(le);
						})
					.join(le + le));
					return dumpChannelArchive(cIdx, idx + 1);
				}
				else
				{
					if (json.contents != null &&
						json.contents.twoColumnBrowseResultsRenderer != null && 
						Std.isOfType(json.contents.twoColumnBrowseResultsRenderer.tabs, Array))
					{
						var contents:Array<Dynamic> = [];
						var tabs:Array<Dynamic> = json.contents.twoColumnBrowseResultsRenderer.tabs;
						for (tab in tabs)
						{
							if (tab.tabRenderer != null &&
								Std.isOfType(tab.tabRenderer.title, String) &&
								tab.tabRenderer.title == "Videos" &&
								tab.tabRenderer.content != null &&
								tab.tabRenderer.content.richGridRenderer != null &&
								tab.tabRenderer.content.richGridRenderer.contents != null &&
								Std.isOfType(tab.tabRenderer.content.richGridRenderer.contents, Array))
							{
								contents = tab.tabRenderer.content.richGridRenderer.contents;
								break;
							}
						}
						if (contents.length == 0) Sys.print("No Video Data Available On This Archive" + le);
						var iterate:Int = 0;
						for (item in contents)
						{
							if (item.richItemRenderer != null &&
								item.richItemRenderer.content != null &&
								item.richItemRenderer.content.videoRenderer != null &&
								Std.isOfType(item.richItemRenderer.content.videoRenderer.videoId, String) &&
								item.richItemRenderer.content.videoRenderer.videoId.length == 11 &&
								item.richItemRenderer.content.videoRenderer.title != null &&
								Std.isOfType(item.richItemRenderer.content.videoRenderer.title.runs, Array) &&
								item.richItemRenderer.content.videoRenderer.title.runs[0] != null &&
								Std.isOfType(item.richItemRenderer.content.videoRenderer.title.runs[0].text, String))
							{
								var videoRenderer:Dynamic = item.richItemRenderer.content.videoRenderer;
								var videoData:Array<String> = [videoRenderer.title.runs[0].text, videoRenderer.videoId];
								Sys.print("   " + videoData[0] + le);
								var contains:Bool = false;
								for (vfd in vfdLines)
								{
									if (vfd[1] == videoData[1]) contains = true;
								}
								if (!contains) vfdLines.push(videoData);
							}
							else
							{
								Sys.print("Video Data Item " + iterate + " Invalid" + le);
							}
							iterate++;
						}
					}
					Sys.print("Updating \"" + vidFile + "\"" + le + le);
					File.saveContent(vidFile, vfdLines
					.map(function(a:Array<String>)
						{
							return a.join(le);
						})
					.join(le + le));
					return dumpChannelArchive(cIdx, idx + 1);
				}
			}
			catch (e:Dynamic)
			{
				Sys.print("Invalid JSON" + le);
				Sys.print(skippingErr);
				return dumpChannelArchive(cIdx, idx + 1);
			}
		}
		requestingArchive = true;
		archiveRequest.request(false);
	}
	
	public function downloadYtDlp():Void
	{
		Sys.print("\"" + ytDlpPath + "\" Does Not Exist!" + le + "Starting Download..." + le);
		var fileRequest:Http = new Http(ytDlpUrl);
		fileRequest.onError = error;
		fileRequest.onBytes = function(data:Bytes)
		{
			Sys.println("Writing...");
			File.saveBytes(ytDlpPath, data);
			Sys.println("\"" + ytDlpPath + "\" Is Now Ready For Use!" + le + le);
			if (!FileSystem.exists(aria2Path)) return downloadAria2();
			downloadVideo();
		}
		fileRequest.request(false);
	}
	
	public function downloadAria2():Void
	{
		Sys.print("\"" + aria2Path + "\" Does Not Exist!" + le + "Starting Download..." + le);
		var fileRequest:Http = new Http(aria2Url);
		fileRequest.onError = error;
		fileRequest.onBytes = function(data:Bytes)
		{
			Sys.println("Writing...");
			File.saveBytes(aria2Path, data);
			Sys.println("\"" + aria2Path + "\" Is Now Ready For Use!" + le + le);
			downloadVideo();
		}
		fileRequest.request(false);
	}
	
	public function queryVid():Void
	{
		var input:Int = Std.parseInt(Sys.stdin().readLine());
		if (input < 1 || input > vfdLines.length) return queryVid();
		Sys.print(le);
		input--;
		queueDownload = vfdLines[input][1];
		if (os > 1) error("Since You Use A Mac, It Is Currently Not Supported For Downloading As I Have Not Figured Out How To Create A Process Out Of .dmg Files So I Deeply Apologize For The Inconvenience (You Can Always Download The Video From Installing aria2 And yt-dlp)" + le + "Video Id: " + queueDownload);
		if (!FileSystem.exists(ytDlpPath)) return downloadYtDlp();
		if (!FileSystem.exists(aria2Path)) return downloadAria2();
		downloadVideo();
	}
	
	public function queryVidFormat():Int
	{
		var input:Int = Std.parseInt(Sys.stdin().readLine());
		if (input < 1 || input > formats.length) return queryVidFormat();
		return input - 1;
	}
	
	public function formatOutput(processOutput:String):String
	{
		var indexOfCut:Int = processOutput.indexOf(strings[0]);
		if (indexOfCut >= 0) indexOfCut += strings[0].length;
		processOutput = processOutput.substring(indexOfCut);
		if (processOutput.toLowerCase().startsWith(strings[1])) processOutput = strings[2];
		var tempStr:String = queueDownload + strings[3];
		indexOfCut = processOutput.indexOf(tempStr);
		if (indexOfCut >= 0) indexOfCut += tempStr.length;
		processOutput = processOutput.substring(indexOfCut);
		return processOutput;
	}
	
	public function downloadVideo():Void
	{
		var exists:Bool = FileSystem.exists(ytDlpConf);
		if (exists) exists = !FileSystem.isDirectory(ytDlpConf);
		if (!exists) File.saveContent(ytDlpConf, YtDlpConfDefault.conf);
		Sys.print("Fetching format list..." + le);
		var archiveUrl:String = "ytarchive:" + queueDownload;
		downloaderProcess = new Process(ytDlpPath, [archiveUrl, "--list-formats"].concat(optArgs));
		var read:Bool = true;
		var extraArgs:Array<String> = [];
		while (read)
		{
			try
			{
				var processOutput:String = formatOutput(downloaderProcess.stdout.readLine());
				var count:Int = processOutput.split("|").length - 1;
				if (processOutput.split("|").length > 2)
				{
					processOutput = processOutput.substring(0, processOutput.indexOf("|")).trim();
					var formatSplit:Array<String> = processOutput.split(" ");
					if (formatSplit.length == 3)
					{
						if (formatSplit[2].split("x").length == 2)
						{
							var duplicate:Bool = false;
							var formatData:Array<String> = [formatSplit[0], formatSplit[1], formatSplit[2]];
							for (format in formats) if (format[0] == formatData[0] && format[1] == formatData[1] && format[2] == formatData[2]) duplicate = true;
							if (!duplicate) formats.push(formatData);
						}
					}
				}
				else
				{
					if (!processOutput.startsWith("[info]") && !processOutput.startsWith("------")) Sys.print(processOutput + le);
				}
			}
			catch (e:Dynamic)
			{
				while (read)
				{
					try
					{
						var processOutput:String = formatOutput(downloaderProcess.stderr.readLine());
						errln(processOutput + le + "Failed to retrieve formats, downloading anyway...");
						read = false;
					}
					catch (e:Dynamic)
					{
						if (formats.length > 0)
						{
							Sys.print(le + "Type One Of The Numbers Below To Select A Video Format:" + le);
							for (i in 0...formats.length) Sys.print("   " + Std.string(i + 1) + "). " + formats[i][2] + " " + formats[i][1] + le);
							Sys.print(le);
							var format:Int = queryVidFormat();
							extraArgs = ["-f", formats[format][0].trim()].concat(extraArgs);
							Sys.print(le + "Downloading in " + formats[format][2] + "..." + le);
						}
						else
						{
							Sys.print("Failed to retrieve formats" + le + "Downloading anyway..." + le);
						}
						read = false;
					}
				}
			}
		}
		downloaderProcess.kill();
		downloaderProcess.close();
		Sys.print("Attempting to download archived youtube video..." + le);
		downloaderProcess = new Process(ytDlpPath, extraArgs.concat([archiveUrl].concat(optArgs)));
		read = true;
		while (read)
		{
			try
			{
				var processOutput:String = formatOutput(downloaderProcess.stdout.readLine());
				Sys.print(processOutput + le);
				if (processOutput.contains(strings[10]) || processOutput.contains(strings[11])) read = false;
			}
			catch (e:Dynamic)
			{
				while (read)
				{
					try
					{
						var processOutput:String = formatOutput(downloaderProcess.stderr.readLine());
						errln(processOutput);
						Sys.print("Attempting to download available youtube video on youtube.com" + le);
						downloaderProcess.kill();
						downloaderProcess.close();
						downloaderProcess = new Process(ytDlpPath, [queueDownload].concat(optArgs));
						read = true;
						while (read)
						{
							try
							{
								var processOutput:String = formatOutput(downloaderProcess.stdout.readLine());
								Sys.print(processOutput + le);
							}
							catch (e:Dynamic)
							{
								read = false;
							}
						}
						read = true;
						while (read)
						{
							try
							{
								var processOutput:String = formatOutput(downloaderProcess.stderr.readLine());
								error(processOutput);
							}
							catch (e:Dynamic)
							{
								read = false;
								error("Failed to fetch anything");
							}
						}
						read = false;
					}
					catch (e:Dynamic)
					{
						read = false;
					}
				}
			}
		}
		Sys.print(le + "Download Finished!" + le);
		Sys.print(quitText + le);
		quit();
	}
}