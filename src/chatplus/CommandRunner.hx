package chatplus;

import chatplus.ChatCommand;
import chatplus.PlayerBook;
import chatplus.PlayerLookup;
import chatplus.Game as G;

/// Runs the mod's chat commands against the game. Each function returns what `ChatBox.handleCommand`
/// returns: the text to send to the selected channel, or "" when nothing is sent.
class CommandRunner {
    // st.Channel constructor index of whispers.
    static inline var WHISPER = 3;
    static inline var LOCAL = 0;
    // The last candidate list shown per name (lower case), for `Name:N`.
    static var lastLists:Map<String, Array<Sighting>> = [];
    // A whisper held back while its recipient is picked, per name (lower case).
    static var heldWhispers:Map<String, String> = [];

    final chat:Dynamic;
    // Set by `find` when it showed a list instead of picking a player.
    var listed = false;
    final player:Dynamic;

    public function new(chat:Dynamic) {
        this.chat = chat;
        player = G.call("ui.BaseElement", "get_myPlayer", chat);
        if (player == null) throw "No player";
    }

    public function run(command:ChatCommand):String {
        return switch (command) {
            case Whisper(name, message): whisper(name, message);
            case Invite(name): invite(name);
            case Leave: leave();
            case Ignore(name): ignore(name);
            case IgnoreList: ignoreList();
            case Unignore(name): unignore(name);
            case Friend(name): friend(name);
            case Clear: clear();
            case Help:
                info(CommandRouter.help(ChatPlus.commandOwners(), ChatPlus.settings.groupHelp).join("\n"));
                "";
            case Check:
                var report = GameCheck.report(GameCheck.missing(Game.exists));
                if (report == null) info(Texts.get("check.ok", [GameCheck.REQUIRED.length, Version.VERSION]));
                else {
                    info(Texts.get("check.version", [Version.VERSION]));
                    ChatPlus.addSystemMessage(report, true, true, null, true);
                }
                "";
            case Usage(text): error(text);
        }
    }

    function whisper(name:String, message:String):String {
        var query = PlayerLookup.parseQuery(name);
        var key = query.name.toLowerCase();
        if (query.pick == null) heldWhispers.remove(key);
        else if (message == "" && heldWhispers.exists(key)) message = heldWhispers.get(key);
        var target = find(name, "/w", ChatPlus.settings.whisperFirstMatch);
        if (target == null) {
            if (listed && message != "") heldWhispers.set(key, message);
            return "";
        }
        heldWhispers.remove(key);
        var channelType = HlxRuntime.resolveType("st.Channel");
        if (channelType == null) throw "Game type unavailable: st.Channel";
        // Same channel as "Send message" in the player menu: it is added to the dropdown and selected.
        var channel = HlxRuntime.constructEnum(channelType, "Player", [target.uid, target.name]);
        G.call("ui.hud.ChatBox", "setChannel", chat, [channel]);
        return message;
    }

    // Same calls as "Invite to group" in the player menu (GameUI.openPlayerInteractionMenu).
    function invite(name:String):String {
        var target = find(name, "/invite", ChatPlus.settings.inviteFirstMatch);
        if (target == null) return "";
        var group = G.field(player, "group");
        for (member in G.elements(G.field(group, "players"))) {
            var uid:String = G.field(member, "uid");
            if (uid == target.uid) return error(Texts.get("invite.inGroup", [target.name]));
        }
        var reason = G.call("st.Group", "hasInvitePlayerAllowed", group);
        if (Type.enumConstructor(reason) != "Ok") return error(G.staticCall("HText", "reason", [reason]));
        G.call("st.player.Whispers", "sendInviteGroup", G.field(player, "whispers"), [target.uid]);
        info(Texts.get("invite.sent", [target.name]));
        return "";
    }

    // Same calls as "Ignore" / "Unignore" / "Add friend" in the player menu. A shared name is never
    // acted on directly: ignoring or befriending the wrong player needs an explicit pick.
    function ignore(name:String):String {
        var target = find(name, "/ignore", false);
        if (target == null) return "";
        if (G.call("st.Player", "isIgnoring", player, [target.uid]) == true) return error(Texts.get("ignore.already", [target.name]));
        G.call("st.Player", "ignorePlayer", player, [target.uid, target.name, true]);
        info(Texts.get("ignore.done", [target.name]));
        return "";
    }

    function ignoreList():String {
        var names = [for (e in ignored()) e.name];
        info(names.length == 0 ? Texts.get("ignore.none") : Texts.get("ignore.list", [names.join(", ")]));
        return "";
    }

    // Searched in the ignore list itself: ignored players' messages are hidden, so the address book may not know them.
    function unignore(name:String):String {
        var key = name.toLowerCase();
        var matches = [for (e in ignored()) if (e.name != null && e.name.toLowerCase() == key) e];
        if (matches.length == 0) return error(Texts.get("unignore.notListed", [name]));
        for (e in matches) G.call("st.Player", "ignorePlayer", player, [e.uid, null, false]);
        info(matches.length == 1 ? Texts.get("unignore.one", [matches[0].name]) : Texts.get("unignore.many", [matches.length, matches[0].name]));
        return "";
    }

    function ignored():Array<{name:String, uid:String}> {
        var list = G.field(G.field(G.field(player, "accountProgress"), "social"), "ignoreList");
        return [for (e in G.elements(list)) {name: G.field(e, "name"), uid: G.field(e, "uid")}];
    }

    function friend(name:String):String {
        var target = find(name, "/friend", false);
        if (target == null) return "";
        var friends = G.field(player, "friendList");
        if (G.call("st.FriendList", "isFriend", friends, [target.uid]) == true) return error(Texts.get("friend.already", [target.name]));
        var targetName = target.name;
        var reason = G.call("st.FriendList", "addFriend", friends, [target.uid, (ok:Bool) -> if (!ok) ChatPlus.addSystemMessage(Texts.get("friend.failed", [targetName]), true, true, null, true)]);
        if (Type.enumConstructor(reason) != "Ok") return error(G.staticCall("HText", "reason", [reason]));
        info(Texts.get("friend.sent", [targetName]));
        return "";
    }

    // Every chat window and speech bubble reads ChatClient.history from its own index. The selected kinds are
    // removed from it and the window is rebuilt, so they stay gone after a scene change or character switch.
    function clear():String {
        var settings = ChatPlus.settings;
        var history = G.staticField("st.player.ChatClient", "history");
        var messages = G.elements(history);
        var i = messages.length;
        while (i-- > 0) {
            var channel = G.field(messages[i], "channel");
            if (channel != null && ClearFilter.removes(Type.enumIndex(channel), settings)) G.call("hl.types.ArrayObj", "splice", history, [i, 1]);
        }
        if (settings.clearWhisperChannels) clearWhisperChannels();
        ChatResize.rebuild(chat, settings.clearSystem);
        if (settings.clearNote) info(Texts.get("clear.done"));
        return "";
    }

    // Removes the whisper channels from the shared option list of the channel dropdown and forgets the
    // last whisper target (/r). The dropdown is rebuilt the way its own set_options does it. A selected
    // whisper channel falls back to Local, the channel a new chat window starts with.
    function clearWhisperChannels():Void {
        var options = G.staticField("ui.hud.ChatBox", "channelOptions");
        var dropdown = G.field(chat, "channelDropdown");
        // The dropdown keeps only an index into the list: read the selected channel before entries are removed.
        var selected = G.call("ui.comp.Dropdown", "get_selectedValue", dropdown);
        var list = G.elements(options);
        var i = list.length;
        while (i-- > 0) if (Type.enumIndex(G.field(list[i], "value")) == WHISPER) G.call("hl.types.ArrayObj", "splice", options, [i, 1]);
        var companion = HlxRuntime.resolveType("ui.hud.ChatBox");
        HlxRuntime.setStaticField(companion, "lastWhisp", null);
        var lastChannel = G.staticField("ui.hud.ChatBox", "lastChannel");
        if (lastChannel != null && Type.enumIndex(lastChannel) == WHISPER) HlxRuntime.setStaticField(companion, "lastChannel", null);
        G.call("ui.comp.Dropdown", "rebuildOptions", dropdown);
        G.call("ui.comp.Dropdown", "updateSelection", dropdown);
        var remaining = G.elements(options);
        var outOfRange = G.integer(G.field(dropdown, "selectedIndex")) >= remaining.length;
        if (outOfRange || (selected != null && Type.enumIndex(selected) == WHISPER)) {
            var fallback = null;
            for (option in remaining) if (fallback == null && Type.enumIndex(G.field(option, "value")) == LOCAL) fallback = G.field(option, "value");
            if (fallback == null && remaining.length > 0) fallback = G.field(remaining[0], "value");
            if (fallback != null) G.call("ui.hud.ChatBox", "setChannel", chat, [fallback]);
        }
    }

    function leave():String {
        var group = G.field(player, "group");
        if (group == null || G.call("st.Group", "get_isSolo", group) == true) return error(Texts.get("leave.solo"));
        G.call("st.Player", "leaveGroup", player);
        return "";
    }

    /// The player meant by `text` (`Name` or `Name:N`), or null after showing an error or a list. With several
    /// accounts of that name it lists all, each line right-clickable, and takes the first when `actOnFirst`.
    function find(text:String, command:String, actOnFirst:Bool):Null<Sighting> {
        var query = PlayerLookup.parseQuery(text);
        var key = query.name.toLowerCase();
        if (query.pick != null) {
            var list = lastLists.get(key);
            if (list == null || query.pick > list.length) {
                error(Texts.get("find.noPick", [text, command, query.name]));
                return null;
            }
            return list[query.pick - 1];
        }
        var live = LivePlayers.read(player);
        ChatPlus.remember(live.onMap.concat(live.group).concat(live.friends));
        var self:String = G.field(player, "uid");
        var found = PlayerLookup.candidates(query.name, live.onMap, live.group, live.friends, ChatPlus.book, self);
        if (found.length == 0) {
            error(Texts.get("find.unknown", [query.name]));
            return null;
        }
        if (found.length == 1) return found[0];
        showChoices(query.name, found, command, actOnFirst);
        return actOnFirst ? found[0] : null;
    }

    function showChoices(name:String, found:Array<Sighting>, command:String, actOnFirst:Bool):Void {
        lastLists.set(name.toLowerCase(), found);
        listed = !actOnFirst;
        var now = Date.now().getTime();
        info(Texts.get(actOnFirst ? "choices.using" : "choices.pick", [found.length, name]));
        for (i in 0...found.length) {
            var s = found[i];
            ChatPlus.addSystemMessage((i + 1) + ") " + s.name + " - " + PlayerLookup.describe(s, now), true, false, {name: s.name, uid: s.uid});
        }
        var hint = Texts.get(actOnFirst ? "hint.another" : "hint.pick", [command, name]);
        if (!actOnFirst && command == "/w") hint += Texts.get("hint.sendsMessage");
        ChatPlus.addSystemMessage(hint + Texts.get("hint.rightClick"), true, false);
    }

    function error(text:String):String {
        G.call("ui.hud.ChatBox", "chatError", chat, [NoteFormat.PREFIX + text]);
        return "";
    }

    function info(text:String):Void {
        ChatPlus.addSystemMessage(text, true);
    }
}
