package chatplus;

import haxe.Json;

/// The mod's options, stored as JSON. Keys missing from the file keep their default.
class Settings {
    /// `[HH:MM]` in front of player messages.
    public var timestamps = true;
    /// Keep chat messages and whisper channels when switching character.
    public var keepHistory = true;
    /// System line `------ character switch ------` in the chat at each character switch (needs `keepHistory`).
    public var switchMessage = false;
    /// Keep the address book of seen players (`players.json`) across game restarts, for `/w` and `/invite`.
    public var rememberPlayers = true;
    /// `/invite` with a name several accounts share: invite the best match right away (and list all).
    public var inviteFirstMatch = true;
    /// `/w` with a name several accounts share: whisper the best match right away. Off: list them and keep the message until one is picked.
    public var whisperFirstMatch = false;
    /// Most messages kept across a character switch; older ones are dropped at the switch.
    public var historyLimit = 500;

    public function new() {}

    /// Settings from JSON text. Throws on invalid JSON.
    public static function parse(json:String):Settings {
        var s = new Settings();
        var data:Dynamic = Json.parse(json);
        if (Std.isOfType(data.timestamps, Bool)) s.timestamps = data.timestamps;
        if (Std.isOfType(data.keepHistory, Bool)) s.keepHistory = data.keepHistory;
        if (Std.isOfType(data.switchMessage, Bool)) s.switchMessage = data.switchMessage;
        if (Std.isOfType(data.rememberPlayers, Bool)) s.rememberPlayers = data.rememberPlayers;
        if (Std.isOfType(data.inviteFirstMatch, Bool)) s.inviteFirstMatch = data.inviteFirstMatch;
        if (Std.isOfType(data.whisperFirstMatch, Bool)) s.whisperFirstMatch = data.whisperFirstMatch;
        if (Std.isOfType(data.historyLimit, Int) && data.historyLimit > 0) s.historyLimit = data.historyLimit;
        return s;
    }

    public function toJson():String {
        return Json.stringify({timestamps: timestamps, keepHistory: keepHistory, switchMessage: switchMessage, rememberPlayers: rememberPlayers,
            inviteFirstMatch: inviteFirstMatch, whisperFirstMatch: whisperFirstMatch, historyLimit: historyLimit}, null, "  ");
    }
}
