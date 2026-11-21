package chatplus;

import hlx.runtime.HlxPrefixControl;
import sys.FileSystem;
import sys.io.File;
import chatplus.Game as G;

/// Chat improvements: a timestamp in front of every player message, and chat history and whisper
/// channels kept across a character switch. Options are in `hlx/mods/chat-plus/settings.json`.
@:build(hlx.runtime.Mod.build())
class ChatPlus {
    static inline var SETTINGS_FILE = "hlx/mods/chat-plus/settings.json";
    static inline var SEPARATOR = "──── character switch ────";
    // st.Channel constructors without a sender: the game already puts the time in their header.
    static inline var CHANNEL_SYSTEM = 2;
    static inline var CHANNEL_SYSTEM_EVENT = 5;

    static var settings:Settings;
    static var separators:Separators;

    static function main():Void {
        separators = new Separators();
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
            trimHistory(settings.historyLimit);
            separators.addSwitch(Sys.time());
        } catch (error:Dynamic) log("keeping the chat history", error);
        return Skip;
    }

    // Keeps the whisper channels of the dropdown.
    @:hlx.prefix(ui.hud.ChatBox.resetChannels)
    static function beforeResetChannels():HlxPrefixControl {
        return settings.keepHistory ? Skip : Continue;
    }

    // Each scene builds a new chat window, which shows the whole history again from the first message.
    @:hlx.postfix(ui.hud.ChatBox.init)
    static function afterChatBoxInit(instance:Dynamic, result:Void):Void {
        separators.startWindow();
    }

    @:hlx.postfix(ui.hud.ChatBoxMessage.init)
    static function afterChatBoxMessageInit(instance:Dynamic, result:Void):Void {
        try decorate(instance) catch (error:Dynamic) log("adding the timestamp", error);
    }

    static function decorate(line:Dynamic):Void {
        var message = G.field(line, "message");
        var stamp:Null<Float> = G.field(message, "localStamp");
        if (stamp == null) return;
        var separator = separators.before(stamp) && settings.keepHistory;
        var channel = G.field(message, "channel");
        var channelIndex = Type.enumIndex(channel);
        var prefix = "";
        if (separator) prefix += withColor(SEPARATOR, "Chat_System") + "<br/>";
        if (settings.timestamps && channelIndex != CHANNEL_SYSTEM && channelIndex != CHANNEL_SYSTEM_EVENT) {
            var time = ChatTime.format(stamp, Sys.time(), Date.now().getTime());
            var color:String = G.staticCall("ui.hud.ChatBoxMessage", "getChannelColor", [channel]);
            prefix += withColor("[" + time + "] ", color);
        }
        if (prefix == "") return;
        var text = G.field(line, "msgText");
        var current:String = G.field(text, "prevUnformatted");
        G.call("ui.comp.FmtText", "set_text", text, [prefix + (current == null ? "" : current)]);
    }

    static function withColor(text:String, color:String):String {
        return G.staticCall("HText", "withColor", [text, color]);
    }

    // Runs while the character selection is open: no chat window reads the history then.
    static function trimHistory(limit:Int):Void {
        var history = G.staticField("st.player.ChatClient", "history");
        var extra = G.integer(G.field(history, "length")) - limit;
        if (extra > 0) G.call("hl.types.ArrayObj", "splice", history, [0, extra]);
    }

    static function log(action:String, error:Dynamic):Void {
        trace("[ChatPlus] error while " + action + ": " + Std.string(error));
    }
}
