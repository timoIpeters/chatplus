package chatplus;

import hlx.runtime.HlxPrefixControl;
import sys.FileSystem;
import sys.io.File;
import chatplus.Game as G;

/// Chat improvements: a timestamp in front of every player message, and chat history and whisper
/// channels kept across a character switch, marked by a system line. Options are in `hlx/mods/chat-plus/settings.json`.
@:build(hlx.runtime.Mod.build())
class ChatPlus {
    static inline var SETTINGS_FILE = "hlx/mods/chat-plus/settings.json";
    static inline var SEPARATOR = "──── character switch ────";
    // st.Channel constructors without a sender: the game already puts the time in their header.
    static inline var CHANNEL_SYSTEM = 2;
    static inline var CHANNEL_SYSTEM_EVENT = 5;

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
            addSeparator(history);
        } catch (error:Dynamic) log("keeping the chat history", error);
        return Skip;
    }

    // Keeps the whisper channels of the dropdown.
    @:hlx.prefix(ui.hud.ChatBox.resetChannels)
    static function beforeResetChannels():HlxPrefixControl {
        return settings.keepHistory ? Skip : Continue;
    }

    @:hlx.postfix(ui.hud.ChatBoxMessage.init)
    static function afterChatBoxMessageInit(instance:Dynamic, result:Void):Void {
        try decorate(instance) catch (error:Dynamic) log("adding the timestamp", error);
    }

    static function decorate(line:Dynamic):Void {
        var message = G.field(line, "message");
        var stamp:Null<Float> = G.field(message, "localStamp");
        if (stamp == null) return;
        var channel = G.field(message, "channel");
        var channelIndex = Type.enumIndex(channel);
        if (!settings.timestamps || channelIndex == CHANNEL_SYSTEM || channelIndex == CHANNEL_SYSTEM_EVENT) return;
        var time = ChatTime.format(stamp, Sys.time(), Date.now().getTime());
        var color:String = G.staticCall("ui.hud.ChatBoxMessage", "getChannelColor", [channel]);
        var prefix = withColor("[" + time + "] ", color);
        var text = G.field(line, "msgText");
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
        var count = G.integer(G.field(history, "length"));
        if (count == 0) return;
        var last = G.call("hl.types.ArrayObj", "getDyn", history, [count - 1]);
        if (G.field(last, "text") == SEPARATOR) return;
        var channelType = HlxRuntime.resolveType("st.Channel");
        if (channelType == null) throw "Game type unavailable: st.Channel";
        var channel = HlxRuntime.constructEnum(channelType, "System", [null]);
        // localReceiveMessage only stamps the message and appends it to the static history; it never reads `this`.
        G.call("st.player.ChatClient", "localReceiveMessage", null, [{channel: channel, sender: null, text: SEPARATOR, notify: null, args: null}]);
    }

    static function log(action:String, error:Dynamic):Void {
        trace("[ChatPlus] error while " + action + ": " + Std.string(error));
    }
}
