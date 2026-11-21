package chatplus;

import haxe.Json;

/// An on/off option: the `Settings` field it sets and the page section it belongs to (a `SECTIONS` id).
/// Its label and tooltip are the texts `set.<key>.label` and `set.<key>.tip`.
typedef Toggle = {key:String, section:String};

/// A section of the settings page: heading text `title.<id>`, its checkboxes (`Toggle.section`), then its sliders.
typedef Section = {id:String, sliders:Array<String>};

/// The mod's options, stored as JSON. Keys missing from the file keep their default.
class Settings {
    /// The on/off options in page order. Each `key` is a `Bool` field of this class.
    public static final TOGGLES:Array<Toggle> = [
        {key: "timestamps", section: "chat"},
        {key: "rememberClosed", section: "chat"},
        {key: "keepHistory", section: "switch"},
        {key: "switchMessage", section: "switch"},
        {key: "rememberPlayers", section: "players"},
        {key: "inviteFirstMatch", section: "players"},
        {key: "whisperFirstMatch", section: "players"},
        {key: "clearAll", section: "clear"},
        {key: "clearGroup", section: "clear"},
        {key: "clearLocal", section: "clear"},
        {key: "clearWhispers", section: "clear"},
        {key: "clearSystem", section: "clear"},
        {key: "clearWhisperChannels", section: "clear"},
        {key: "clearNote", section: "clear"},
        {key: "showErrors", section: "debug"},
    ];
    /// The page sections in order.
    public static final SECTIONS:Array<Section> = [
        {id: "chat", sliders: []},
        {id: "switch", sliders: ["historyLimit"]},
        {id: "players", sliders: []},
        {id: "clear", sliders: []},
        {id: "size", sliders: ["chatWidth", "chatHeight"]},
        {id: "debug", sliders: []},
    ];
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

    /// Whether `json` lacks one of the keys `toJson` writes. Better Mod Settings shows a missing key as off,
    /// while the mod uses its default, so such a file is written back complete.
    public static function incomplete(json:String):Bool {
        var data:Dynamic = Json.parse(json);
        var saved:Dynamic = Json.parse(new Settings().toJson());
        for (key in Reflect.fields(saved)) if (!Reflect.hasField(data, key)) return true;
        return false;
    }

    /// The settings page for Better Mod Settings (`configFormats.json` in the mod folder), in the current language.
    public static function formatsJson():String {
        var configs:Array<Dynamic> = [];
        for (section in SECTIONS) {
            configs.push({type: "title", label: Texts.get("title." + section.id)});
            for (t in TOGGLES) if (t.section == section.id) configs.push(checkbox(t));
            for (key in section.sliders) configs.push(switch (key) {
                case "historyLimit": slider(key, HISTORY_MIN, HISTORY_MAX, HISTORY_STEP);
                case "chatWidth": slider(key, CHAT_WIDTH_MIN, CHAT_WIDTH_MAX, CHAT_SIZE_STEP);
                default: slider(key, CHAT_HEIGHT_MIN, CHAT_HEIGHT_MAX, CHAT_SIZE_STEP);
            });
        }
        return Json.stringify({configs: configs, displayName: "Chat Plus", schemaVersion: 1}, null, "  ");
    }

    static function checkbox(t:Toggle):Dynamic {
        return {key: t.key, label: Texts.get("set." + t.key + ".label"), type: "checkbox", tooltip: tooltip(t.key)};
    }

    static function slider(key:String, min:Int, max:Int, step:Int):Dynamic {
        return {key: key, label: Texts.get("set." + key + ".label"), type: "slider", min: min, max: max, step: step, tooltip: tooltip(key)};
    }

    static function tooltip(key:String):Dynamic {
        return {enabled: true, tooltipText: Texts.get("set." + key + ".tip")};
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
