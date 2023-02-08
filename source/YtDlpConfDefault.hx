package;

import Main.*;

class YtDlpConfDefault
{
	public static var conf:String =
	"--downloader aria2c --downloader-args aria2c:'-c -j 5 -x 6 -s 4 -k 5M'" + le +
	"--downloader 'dash,m3u8:native'" + le +
	"--restrict-filenames" + le +
	"--merge-output-format mkv" + le;
}