# Youtube Archive Downloader
* I made this tool using **Haxe** and the reason for it is that if you want to download multiple videos and select one then you can store all of those in a singular file named `yad.videos`.
* Another reason why i made and developed this tool is for the sole purpose of scraping off youtube channel content. (specifically channels who have privated their videos but still have an archive of their channel like Composerily)
* The tool basically crawls through the wayback machine to fetch the channel's video list then dumps it onto `yad.videos` and you can specify the youtube channel links you'd want it to fetch in `yad.channels`.
* There is a specific type of formatting for `yad.videos` and `yad.channels` so please read the **Usage** section of this README document.
* Please report issues if you experience any, specially cross platform issues like this tool having problems on linux. (mac is not supported yet but if any genius can figure it out to work then report the issue)
* This tool uses `yt-dlp` (https://github.com/yt-dlp/yt-dlp) for downloading archived or non archived video files and `aria2` for faster downloads (https://github.com/aria2/aria2).
* This tool still probably has bugs and is a little complicated to use.

# Setup
* You can go towards the releases page of this repository (i recommend doing it after reading this document as the **Usage** section is very crucial in guiding you on how to use this tool. (https://github.com/GrowtopiaFli/yad/releases)
* Make sure you know if your computer is either 32 bit or 64 bit so that you know what file you should download.
* The .hl file in the releases page is a file you can use on hashlink which is a haxe virtual machine (https://hashlink.haxe.org) you can search about running .hl files with hashlink online.
* Since i use a **Windows** computer, i have not exported an executable (and yes, anything you can run is called an executable, not only `.exe` files) for **Linux** and **Mac** so if you want to run the tool, you could use something like wine, use hashlink or read the compile section of this document. (though keep in mind that i have no idea how to compile with **Linux** and **Mac** so if you DO encounter issues, make sure to report it here)
* You can just simply run the tool like a normal application.

# Usage
* Just look at whatever the application is saying and comply.
* You can search up online on how to use `yt-dlp.conf` which is the config file for `yt-dlp`.
* `yad.videos` has a format like this:
  ```
  VIDEO_TITLE_1
  VIDEO_ID_1

  VIDEO_TITLE_2
  VIDEO_ID_2

  VIDEO_TITLE_3
  VIDEO_ID_3
  ```
  * You can add as many videos as you want.
  * lol
* If the tool fails to download an archived youtube video, then it automatically starts downloading an available youtube video with that link/id.
