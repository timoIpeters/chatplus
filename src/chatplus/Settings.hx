package chatplus;

import haxe.Json;

/// The mod's options, stored as JSON. Keys missing from the file keep their default.
class Settings {
    /// `[HH:MM]` in front of player messages.
    public var timestamps = true;
    /// Keep chat messages and whisper channels when switching character.
    public var keepHistory = true;
    /// Most messages kept across a character switch; older ones are dropped at the switch.
    public var historyLimit = 500;

    public function new() {}

    /// Settings from JSON text. Throws on invalid JSON.
    public static function parse(json:String):Settings {
        var s = new Settings();
        var data:Dynamic = Json.parse(json);
        if (Std.isOfType(data.timestamps, Bool)) s.timestamps = data.timestamps;
        if (Std.isOfType(data.keepHistory, Bool)) s.keepHistory = data.keepHistory;
        if (Std.isOfType(data.historyLimit, Int) && data.historyLimit > 0) s.historyLimit = data.historyLimit;
        return s;
    }

    public function toJson():String {
        return Json.stringify({timestamps: timestamps, keepHistory: keepHistory, historyLimit: historyLimit}, null, "  ");
    }
}
