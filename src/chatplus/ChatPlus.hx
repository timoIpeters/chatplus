package chatplus;

import hlx.runtime.HlxPrefixControl;
import hlx.runtime.HlxPrefixResult;
import sys.FileSystem;
import sys.io.File;
import chatplus.ChatCommand;
import chatplus.Game as G;

/// Chat improvements: a timestamp in front of every player message, chat history and whisper
/// channels kept across a character switch, and more chat commands (`/help`). Options are in `hlx/mods/chat-plus/settings.json`.
@:build(hlx.runtime.Mod.build())
class ChatPlus {
    static inline var SETTINGS_FILE = "hlx/mods/chat-plus/settings.json";
    static inline var SEPARATOR = "------ character switch ------";
    // st.Channel constructors without a sender: the game already puts the time in their header.
    static inline var CHANNEL_SYSTEM = 2;
    static inline var CHANNEL_SYSTEM_EVENT = 5;
    // Field in `args` of the mod's own system messages. The game reads `args` only for `notify` messages.
    static inline var PLAIN_MARK = "chatPlus";

    static var settings:Settings;

    static function main():Void {
        settings = loadSettings();
    }

    static function loadSettings():Settings {
        try {
            if (FileSystem.exists(SETTINGS_FILE)) return Settings.parse(File.getContent(SETTINGS_FILE));
            // Written once so the options can be edited by hand.
            var defaults = new Settings();
            File.saveContent(SETTINGS_FILE, defaults.toJson());
            return defaults;
        } catch (error:Dynamic) {
            log("reading " + SETTINGS_FILE + ", using the defaults", error);
            return new Settings();
        }
    }

    // Called by MenuApp.init, i.e. at game start and on every return to the character selection.
    @:hlx.prefix(st.player.ChatClient.resetHistory)
    static function beforeResetHistory():HlxPrefixControl {
        if (!settings.keepHistory) return Continue;
        try {
            var history = G.staticField("st.player.ChatClient", "history");
            trimHistory(history, settings.historyLimit);
            if (settings.switchMessage) addSeparator(history);
        } catch (error:Dynamic) log("keeping the chat history", error);
        return Skip;
    }

    // Keeps the whisper channels of the dropdown.
    @:hlx.prefix(ui.hud.ChatBox.resetChannels)
    static function beforeResetChannels():HlxPrefixControl {
        return settings.keepHistory ? Skip : Continue;
    }

    // Mod commands are handled here; the game's own commands (/all, /p, /r, ...) go on to the game.
    @:hlx.prefix(ui.hud.ChatBox.handleCommand)
    static function beforeHandleCommand(instance:Dynamic, command:String, args:Dynamic):HlxPrefixResult<String> {
        try {
            var words = [for (a in G.elements(args)) Std.string(a)];
            var parsed = ChatCommands.parse(command, words);
            if (parsed == null) return Continue;
            return SkipWith(new CommandRunner(instance).run(parsed));
        } catch (error:Dynamic) {
            log("running /" + command, error);
            return Continue;
        }
    }

    @:hlx.postfix(ui.hud.ChatBoxMessage.init)
    static function afterChatBoxMessageInit(instance:Dynamic, result:Void):Void {
        try decorate(instance) catch (error:Dynamic) log("adding the timestamp", error);
    }

    static function decorate(line:Dynamic):Void {
        var message = G.field(line, "message");
        var stamp:Null<Float> = G.field(message, "localStamp");
        if (stamp == null) return;
        var text = G.field(line, "msgText");
        if (G.field(G.field(message, "args"), PLAIN_MARK) == true) {
            // The mod's own notes: no "[HH:MM] [System]" header, own colors and prefix (NoteFormat).
            var note:String = G.field(message, "text");
            G.call("ui.comp.FmtText", "set_text", text, [NoteFormat.toMarkup(note)]);
            return;
        }
        var channel = G.field(message, "channel");
        var channelIndex = Type.enumIndex(channel);
        if (!settings.timestamps || channelIndex == CHANNEL_SYSTEM || channelIndex == CHANNEL_SYSTEM_EVENT) return;
        var time = ChatTime.format(stamp, Sys.time(), Date.now().getTime());
        var color:String = G.staticCall("ui.hud.ChatBoxMessage", "getChannelColor", [channel]);
        var prefix = withColor("[" + time + "] ", color);
        var current:String = G.field(text, "prevUnformatted");
        G.call("ui.comp.FmtText", "set_text", text, [prefix + (current == null ? "" : current)]);
    }

    static function withColor(text:String, color:String):String {
        return G.staticCall("HText", "withColor", [text, color]);
    }

    // Runs while the character selection is open: no chat window reads the history then.
    static function trimHistory(history:Dynamic, limit:Int):Void {
        var extra = G.integer(G.field(history, "length")) - limit;
        if (extra > 0) G.call("hl.types.ArrayObj", "splice", history, [0, extra]);
    }

    // A system message, so every chat window shows it below the previous character's messages.
    // Not added to an empty history (game start) or twice in a row (switching without chatting).
    static function addSeparator(history:Dynamic):Void {
        var messages = G.elements(history);
        if (messages.length == 0) return;
        var lastText:String = G.field(messages[messages.length - 1], "text");
        if (lastText == SEPARATOR) return;
        addSystemMessage(SEPARATOR);
    }

    /// Adds a system message to the chat history; every chat window shows it. A `plain` message is
    /// one of the mod's notes: shown by `NoteFormat` instead of the `[HH:MM] [System]` header, and may span several lines (`\n`).
    public static function addSystemMessage(text:String, plain = false):Void {
        var channelType = HlxRuntime.resolveType("st.Channel");
        if (channelType == null) throw "Game type unavailable: st.Channel";
        var channel = HlxRuntime.constructEnum(channelType, "System", [null]);
        // localReceiveMessage only stamps the message and appends it to the static history; it never reads `this`.
        G.call("st.player.ChatClient", "localReceiveMessage", null, [{channel: channel, sender: null, text: text, notify: null, args: plain ? {chatPlus: true} : null}]);
    }

    static function log(action:String, error:Dynamic):Void {
        trace("[ChatPlus] error while " + action + ": " + Std.string(error));
    }
}
