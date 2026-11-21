package chatplus;

import haxe.Json;

/// An on/off option: the `Settings` field it sets, its label and tooltip on the settings page, and the
/// page section it belongs to (`Chat` when not set).
typedef Toggle = {key:String, label:String, tooltip:String, ?section:String};

/// The mod's options, stored as JSON. Keys missing from the file keep their default.
class Settings {
    /// The on/off options in page order. Each `key` is a `Bool` field of this class.
    public static final TOGGLES:Array<Toggle> = [
        {key: "timestamps", label: "Timestamps", tooltip: "[HH:MM] in front of every player message: the time your client received it."},
        {key: "keepHistory", label: "Keep chat on character switch", tooltip: "Messages and whisper channels stay after a character switch."},
        {key: "switchMessage", label: "Character switch line", tooltip: "A line \"------ character switch ------\" in the chat at each character switch. Needs \"Keep chat on character switch\"."},
        {key: "rememberClosed", label: "Keep a closed chat closed", tooltip: "A chat closed with its minimize button stays closed when you change scene (dungeon, map, character)."},
        {key: "rememberPlayers", label: "Remember players across restarts", tooltip: "/w and /invite find players you met in earlier sessions. Stored in hlx/mods/chat-plus/players.json."},
        {key: "inviteFirstMatch", label: "Auto-pick shared names for /invite", tooltip: "If several players have the name, invite the most likely one. Off: pick from a list first."},
        {key: "whisperFirstMatch", label: "Auto-pick shared names for /w", tooltip: "If several players have the name, whisper the most likely one. Off: pick from a list first."},
        {key: "showErrors", label: "Show mod errors in the chat", tooltip: "Red [Chat Plus] lines when something of the game the mod uses is missing (e.g. after a game update) or the mod hits an error. Always written to hlx/logs/hlx.log."},
        {key: "clearAll", label: "Clear All messages", tooltip: "/clear removes messages of the All channel.", section: CLEAR_SECTION},
        {key: "clearGroup", label: "Clear Group messages", tooltip: "/clear removes messages of the group channel.", section: CLEAR_SECTION},
        {key: "clearLocal", label: "Clear Local messages", tooltip: "/clear removes messages of the local channel.", section: CLEAR_SECTION},
        {key: "clearWhispers", label: "Clear whisper messages", tooltip: "/clear removes whispers you sent and received.", section: CLEAR_SECTION},
        {key: "clearSystem", label: "Clear system messages", tooltip: "/clear removes game notices and Chat Plus lines.", section: CLEAR_SECTION},
        {key: "clearWhisperChannels", label: "Clear whisper channels", tooltip: "/clear removes the whisper channels from the channel list. /r then has no one to reply to.", section: CLEAR_SECTION},
        {key: "clearNote", label: "Show a note after /clear", tooltip: "A \"Chat cleared\" line after /clear.", section: CLEAR_SECTION},
    ];
    static inline var CLEAR_SECTION = "/clear";
    public static inline var HISTORY_MIN = 100;
    public static inline var HISTORY_MAX = 2000;
    public static inline var HISTORY_STEP = 100;
    /// The game's chat size (`chat-box` style), the smallest the chat can be.
    public static inline var CHAT_WIDTH_MIN = 480;
    public static inline var CHAT_HEIGHT_MIN = 250;
    public static inline var CHAT_WIDTH_MAX = 1920;
    public static inline var CHAT_HEIGHT_MAX = 1080;
    public static inline var CHAT_SIZE_STEP = 10;

    /// `[HH:MM]` in front of player messages.
    public var timestamps = true;
    /// Keep chat messages and whisper channels when switching character.
    public var keepHistory = true;
    /// System line `------ character switch ------` in the chat at each character switch (needs `keepHistory`).
    public var switchMessage = false;
    /// A chat closed with its minimize button stays closed in the next scene.
    public var rememberClosed = true;
    /// Keep the address book of seen players (`players.json`) across game restarts, for `/w` and `/invite`.
    public var rememberPlayers = true;
    /// `/invite` with a name several accounts share: invite the best match right away (and list all).
    public var inviteFirstMatch = true;
    /// `/w` with a name several accounts share: whisper the best match right away. Off: list them and keep the message until one is picked.
    public var whisperFirstMatch = false;
    /// Red chat lines for missing game elements and runtime errors (always in `hlx.log`).
    public var showErrors = true;
    /// What `/clear` removes: messages per channel kind, and the whisper channels of the channel list.
    public var clearAll = true;
    public var clearGroup = true;
    public var clearLocal = true;
    public var clearWhispers = true;
    public var clearSystem = true;
    public var clearWhisperChannels = false;
    /// A "Chat cleared" line after `/clear`.
    public var clearNote = false;
    /// Chat size, changed by dragging its top or right edge.
    public var chatWidth = CHAT_WIDTH_MIN;
    public var chatHeight = CHAT_HEIGHT_MIN;
    /// Most messages kept across a character switch; older ones are dropped at the switch.
    public var historyLimit = 500;

    public function new() {}

    public function get(key:String):Bool {
        return Reflect.field(this, key) == true;
    }

    /// Settings from JSON text. Throws on invalid JSON.
    public static function parse(json:String):Settings {
        var s = new Settings();
        var data:Dynamic = Json.parse(json);
        for (t in TOGGLES) {
            var value = Reflect.field(data, t.key);
            if (Std.isOfType(value, Bool)) Reflect.setField(s, t.key, value);
        }
        if (Std.isOfType(data.historyLimit, Int) && data.historyLimit > 0) s.historyLimit = data.historyLimit;
        if (Std.isOfType(data.chatWidth, Int)) s.chatWidth = Std.int(Math.max(CHAT_WIDTH_MIN, data.chatWidth));
        if (Std.isOfType(data.chatHeight, Int)) s.chatHeight = Std.int(Math.max(CHAT_HEIGHT_MIN, data.chatHeight));
        return s;
    }

    /// The settings page for Better Mod Settings (`configFormats.json` in the mod folder).
    public static function formatsJson():String {
        var configs:Array<Dynamic> = [{type: "title", label: "Chat"}];
        for (t in TOGGLES) if (t.section == null) configs.push(checkbox(t));
        configs.push({
            key: "historyLimit",
            label: "Messages kept on character switch",
            type: "slider",
            min: HISTORY_MIN,
            max: HISTORY_MAX,
            step: HISTORY_STEP,
            tooltip: {enabled: true, tooltipText: "The oldest messages above this number are dropped at a character switch."},
        });
        configs.push({type: "title", label: CLEAR_SECTION});
        for (t in TOGGLES) if (t.section == CLEAR_SECTION) configs.push(checkbox(t));
        configs.push({type: "title", label: "Chat size"});
        configs.push(slider("chatWidth", "Chat width", CHAT_WIDTH_MIN, CHAT_WIDTH_MAX, "Drag the right edge of the chat to change it. The smallest value is the game's size."));
        configs.push(slider("chatHeight", "Chat height", CHAT_HEIGHT_MIN, CHAT_HEIGHT_MAX, "Drag the top edge of the chat to change it. The smallest value is the game's size."));
        return Json.stringify({configs: configs, displayName: "Chat Plus", schemaVersion: 1}, null, "  ");
    }

    static function checkbox(t:Toggle):Dynamic {
        return {key: t.key, label: t.label, type: "checkbox", tooltip: {enabled: true, tooltipText: t.tooltip}};
    }

    static function slider(key:String, label:String, min:Int, max:Int, tooltip:String):Dynamic {
        return {key: key, label: label, type: "slider", min: min, max: max, step: CHAT_SIZE_STEP, tooltip: {enabled: true, tooltipText: tooltip}};
    }

    public function toJson():String {
        var data:Dynamic = {};
        for (t in TOGGLES) Reflect.setField(data, t.key, get(t.key));
        data.historyLimit = historyLimit;
        data.chatWidth = chatWidth;
        data.chatHeight = chatHeight;
        return Json.stringify(data, null, "  ");
    }
}
