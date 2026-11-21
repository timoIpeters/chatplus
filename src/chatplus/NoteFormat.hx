package chatplus;

using StringTools;

/// Markup for the mod's own chat messages: orange text with a `[Chat Plus]` prefix on the first line
/// (left out for follow-up lines of a list).
/// A line `/command ... - description` or `Tab ... - description` shows the command or key part in light blue.
class NoteFormat {
    public static inline var ORANGE = "#FF9933";
    public static inline var LIGHT_BLUE = "#8CC8FF";
    public static inline var PREFIX = "[Chat Plus] ";
    static inline var COMMAND_SEPARATOR = " - ";

    public static function toMarkup(text:String, withPrefix = true):String {
        var lines = text.split("\n");
        var out = [for (i in 0...lines.length) line(i == 0 && withPrefix ? PREFIX + lines[i] : lines[i])];
        return out.join("<br/>");
    }

    static function line(text:String):String {
        var split = text.indexOf(COMMAND_SEPARATOR);
        if (!(text.startsWith("/") || text.startsWith("Tab")) || split < 0) return color(text, ORANGE);
        return color(text.substr(0, split), LIGHT_BLUE) + color(text.substr(split), ORANGE);
    }

    static function color(text:String, hex:String):String {
        return '<font color="$hex">' + text.htmlEscape() + "</font>";
    }
}
