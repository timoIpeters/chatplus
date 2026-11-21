package chatplus;

import hlx.runtime.HlxPrefixControl;
import hlx.runtime.HlxPrefixResult;
import sys.FileSystem;
import sys.io.File;
import chatplus.ChatCommand;
import chatplus.PlayerBook;
import chatplus.Game as G;

/// Chat improvements: a timestamp in front of every player message, chat history and whisper
/// channels kept across a character switch, and more chat commands (`/help`) that find players by name
/// through an address book of seen players. Options: Esc → Mod Settings → Chat Plus (Better Mod Settings),
/// stored in `hlx/config/chat-plus/config.json`.
@:build(hlx.runtime.Mod.build())
class ChatPlus {
    static inline var MOD_NAME = "chat-plus";
    // HLX ModConfig location, read and written by Better Mod Settings.
    static inline var SETTINGS_FILE = "hlx/config/chat-plus/config.json";
    // Location of the options before they moved to the HLX config folder.
    static inline var OLD_SETTINGS_FILE = "hlx/mods/chat-plus/settings.json";
    // The settings page Better Mod Settings shows for this mod.
    static inline var FORMATS_FILE = "hlx/mods/chat-plus/configFormats.json";
    // Published by Better Mod Settings after it saved this mod's config.json.
    static inline var CONFIG_CHANGED = "better-mod-settings/config-changed/";
    static inline var PLAYERS_FILE = "hlx/mods/chat-plus/players.json";
    // Seconds between writes of the address book while players are being recorded.
    static inline var SAVE_INTERVAL = 30;
    // st.Channel constructors without a sender: the game already puts the time in their header.
    static inline var CHANNEL_SYSTEM = 2;
    static inline var CHANNEL_SYSTEM_EVENT = 5;
    // Field in `args` of the mod's own system messages. The game reads `args` only for `notify` messages.
    static inline var PLAIN_MARK = "chatPlus";
    static inline var NO_PREFIX_MARK = "noPrefix";
    static inline var ERROR_MARK = "error";
    static inline var MINIMIZED = "minimized";

    public static var settings:Settings;
    /// Players seen this session, and in earlier sessions when `rememberPlayers` is on.
    public static var book:PlayerBook;
    static var bookDirty = false;
    // The chat window of the previous scene, to carry its closed state over to the next one.
    static var previousChat:Dynamic;
    static var bookSaved = 0.0;
    // Error notes wait here until the first chat window exists; each kind of error is shown once per session.
    static var pendingErrors:Array<String> = [];
    static var reportedErrors:Map<String, Bool> = [];
    static var chatReady = false;
    static var flushing = false;

    static function main():Void {
        trace("[ChatPlus] version " + Version.VERSION);
        settings = loadSettings();
        book = loadBook();
        updateLanguage();
        writeFormats();
        hlx.runtime.Bus.subscribe(CONFIG_CHANGED + MOD_NAME, onConfigChanged);
        checkGame();
    }

    // Reflection works in main() (hlx-core 0.0.11), so a renamed game function is found before it is needed.
    static function checkGame():Void {
        try {
            var missing = GameCheck.missing(Game.exists);
            for (r in missing) trace("[ChatPlus] game element not found: " + GameCheck.name(r) + " (" + r.feature + ")");
            var note = GameCheck.report(missing);
            if (note != null) showError(note);
        } catch (error:Dynamic) log("checking the game", error);
    }

    static function showError(text:String):Void {
        if (!settings.showErrors) return;
        pendingErrors.push(text);
        flushErrors();
    }

    static function flushErrors():Void {
        if (!chatReady || flushing) return;
        flushing = true;
        try {
            while (pendingErrors.length > 0) addSystemMessage(pendingErrors.shift(), true, true, null, true);
        } catch (error:Dynamic) trace("[ChatPlus] error while showing an error in the chat: " + Std.string(error));
        flushing = false;
    }

    /// Writes the options, e.g. after the chat was resized.
    public static function saveSettings():Void {
        try File.saveContent(SETTINGS_FILE, settings.toJson()) catch (error:Dynamic) log("writing " + SETTINGS_FILE, error);
    }

    static function onConfigChanged(payload:Dynamic):Void {
        var rememberedBefore = settings.rememberPlayers;
        var widthBefore = settings.chatWidth;
        settings = loadSettings();
        var resize = ChatResize.current;
        if (resize != null && settings.chatWidth != widthBefore) try resize.rebuildLines() catch (error:Dynamic) log("rebuilding the chat lines", error);
        if (settings.rememberPlayers && !rememberedBefore) {
            bookDirty = true;
            saveBook(true);
        }
    }

    // The game keeps its language in Options.language (set by DataTools.setLang). At mod start the game's
    // options may not be loaded yet, so it is read again for every chat window.
    static function updateLanguage():Bool {
        var code:String = null;
        try code = G.staticField("Options", "language") catch (_:Dynamic) {}
        var lang = code == "de" ? "de" : "en";
        if (lang == Texts.lang) return false;
        Texts.lang = lang;
        return true;
    }

    // Rewritten when it differs, so the settings page always matches this version of the mod and the game's language.
    static function writeFormats():Void {
        try {
            var json = Settings.formatsJson();
            if (!FileSystem.exists(FORMATS_FILE) || File.getContent(FORMATS_FILE) != json) File.saveContent(FORMATS_FILE, json);
        } catch (error:Dynamic) log("writing " + FORMATS_FILE, error);
    }

    static function loadBook():PlayerBook {
        if (!settings.rememberPlayers) return new PlayerBook();
        try {
            return FileSystem.exists(PLAYERS_FILE) ? PlayerBook.fromJson(File.getContent(PLAYERS_FILE)) : new PlayerBook();
        } catch (error:Dynamic) {
            log("reading " + PLAYERS_FILE + ", starting an empty address book", error);
            return new PlayerBook();
        }
    }

    /// Writes the address book when it changed, at most every `SAVE_INTERVAL` seconds unless `now` is set.
    public static function saveBook(now = false):Void {
        if (!settings.rememberPlayers || !bookDirty) return;
        if (!now && Sys.time() - bookSaved < SAVE_INTERVAL) return;
        try {
            File.saveContent(PLAYERS_FILE, book.toJson());
            bookDirty = false;
            bookSaved = Sys.time();
        } catch (error:Dynamic) log("writing " + PLAYERS_FILE, error);
    }

    public static function remember(sightings:Array<Sighting>):Void {
        for (s in sightings) book.record(s);
        if (sightings.length > 0) bookDirty = true;
        saveBook();
    }

    static function loadSettings():Settings {
        try {
            if (FileSystem.exists(SETTINGS_FILE)) {
                var json = File.getContent(SETTINGS_FILE);
                var loaded = Settings.parse(json);
                // Options added by a newer version get their default written into the file.
                if (Settings.incomplete(json)) File.saveContent(SETTINGS_FILE, loaded.toJson());
                return loaded;
            }
            // Written once, from the old location if there is one, so Better Mod Settings shows the current values.
            var initial = FileSystem.exists(OLD_SETTINGS_FILE) ? Settings.parse(File.getContent(OLD_SETTINGS_FILE)) : new Settings();
            FileSystem.createDirectory(haxe.io.Path.directory(SETTINGS_FILE));
            File.saveContent(SETTINGS_FILE, initial.toJson());
            return initial;
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

    // Every scene builds a new chat window: it takes over the closed state of the previous one,
    // and it is a good moment to note the players around.
    @:hlx.postfix(ui.hud.ChatBox.init)
    static function afterChatBoxInit(instance:Dynamic, result:Void):Void {
        if (updateLanguage()) writeFormats();
        chatReady = true;
        flushErrors();
        try keepClosed(instance) catch (error:Dynamic) log("keeping the chat closed", error);
        try new ChatResize(instance) catch (error:Dynamic) log("adding the chat resize handles", error);
        previousChat = instance;
        try {
            var player = G.call("ui.BaseElement", "get_myPlayer", instance);
            if (player == null) return;
            var live = LivePlayers.read(player);
            remember(live.onMap.concat(live.group).concat(live.friends));
        } catch (error:Dynamic) log("noting the players around", error);
    }

    // Every chat message, received or sent, once: its sender and whisper partner go into the address book.
    @:hlx.postfix(st.player.ChatClient.localReceiveMessage)
    static function afterLocalReceiveMessage(instance:Dynamic, message:Dynamic, result:Void):Void {
        try {
            if (G.field(G.field(message, "args"), PLAIN_MARK) == true) return;
            remember(LivePlayers.fromMessage(message, Date.now().getTime()));
        } catch (error:Dynamic) log("noting a chat sender", error);
    }

    // The game re-applies the chat's style (480×250) in this pass when the chat or a line changes state
    // (hover, focus); setting the size right after it keeps that from showing for a frame.
    @:hlx.postfix(h2d.domkit.Style.sync)
    static function afterStyleSync(instance:Dynamic, dt:Null<Float>, result:Int):Int {
        var resize = ChatResize.current;
        if (resize != null) try resize.applySize() catch (error:Dynamic) log("applying the chat size", error);
        return result;
    }

    // The minimize button toggles the CSS class "minimized"; focusing the input (Enter) removes it.
    // The old window's class is its state at the scene change, however it was reached.
    static function keepClosed(chat:Dynamic):Void {
        if (!settings.rememberClosed || previousChat == null) return;
        if (G.call("domkit.Properties", "hasClass", G.field(previousChat, "dom"), [MINIMIZED]) == true)
            G.call("domkit.Properties", "toggleClass", G.field(chat, "dom"), [MINIMIZED, true]);
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
        var args = G.field(message, "args");
        if (G.field(args, PLAIN_MARK) == true) {
            // The mod's own notes: no "[HH:MM] [System]" header, own colors and prefix (NoteFormat).
            var note:String = G.field(message, "text");
            G.call("ui.comp.FmtText", "set_text", text, [NoteFormat.toMarkup(note, G.field(args, NO_PREFIX_MARK) != true, G.field(args, ERROR_MARK) == true)]);
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
        if (lastText == Texts.get("separator")) return;
        addSystemMessage(Texts.get("separator"));
    }

    /// Adds a system message to the chat history; every chat window shows it. A `plain` message is
    /// one of the mod's notes: shown by `NoteFormat` instead of the `[HH:MM] [System]` header, and may span several lines (`\n`).
    /// With `sender`, right-clicking the line opens the game's player menu for that account.
    public static function addSystemMessage(text:String, plain = false, prefix = true, ?sender:{name:String, uid:String}, error = false):Void {
        var channelType = HlxRuntime.resolveType("st.Channel");
        if (channelType == null) throw "Game type unavailable: st.Channel";
        var channel = HlxRuntime.constructEnum(channelType, "System", [null]);
        // localReceiveMessage only stamps the message and appends it to the static history; it never reads `this`.
        G.call("st.player.ChatClient", "localReceiveMessage", null, [{channel: channel, sender: sender, text: text, notify: null, args: plain ? {chatPlus: true, noPrefix: !prefix, error: error} : null}]);
    }

    /// Writes the error to `hlx.log`, and once per kind of error to the chat when `showErrors` is on.
    public static function log(action:String, error:Dynamic):Void {
        trace("[ChatPlus] error while " + action + ": " + Std.string(error));
        if (settings == null || reportedErrors.exists(action)) return;
        reportedErrors.set(action, true);
        showError(Texts.get("error.while", [action, Std.string(error)]));
    }
}
