import chatplus.Settings;
import chatplus.Texts;

/// Writes the English settings page (`configFormats.json`) the mod would write at start, so a release
/// contains it and Better Mod Settings shows the page on the first start.
class WriteFormats {
    static function main():Void {
        var args = Sys.args();
        if (args.length != 1) {
            Sys.println("Usage: haxe formats.hxml <output file>");
            Sys.exit(1);
        }
        Texts.lang = "en";
        sys.io.File.saveContent(args[0], Settings.formatsJson());
        Sys.println("wrote " + args[0]);
    }
}
