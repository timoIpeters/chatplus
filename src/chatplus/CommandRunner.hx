package chatplus;

import chatplus.ChatCommand;
import chatplus.PlayerBook;
import chatplus.PlayerLookup;
import chatplus.Game as G;

/// Runs the mod's chat commands against the game. Each function returns what `ChatBox.handleCommand`
/// returns: the text to send to the selected channel, or "" when nothing is sent.
class CommandRunner {
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
            case Help:
                info(ChatCommands.HELP.join("\n"));
                "";
            case Check:
                var report = GameCheck.report(GameCheck.missing(Game.exists));
                if (report == null) info("All " + GameCheck.REQUIRED.length + " game elements the mod uses were found.");
                else ChatPlus.addSystemMessage(report, true, true, null, true);
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
            if (uid == target.uid) return error(target.name + " is already in your group");
        }
        var reason = G.call("st.Group", "hasInvitePlayerAllowed", group);
        if (Type.enumConstructor(reason) != "Ok") return error(G.staticCall("HText", "reason", [reason]));
        G.call("st.player.Whispers", "sendInviteGroup", G.field(player, "whispers"), [target.uid]);
        info("Group invite sent to " + target.name);
        return "";
    }

    // Same calls as "Ignore" / "Unignore" / "Add friend" in the player menu. A shared name is never
    // acted on directly: ignoring or befriending the wrong player needs an explicit pick.
    function ignore(name:String):String {
        var target = find(name, "/ignore", false);
        if (target == null) return "";
        if (G.call("st.Player", "isIgnoring", player, [target.uid]) == true) return error(target.name + " is already ignored");
        G.call("st.Player", "ignorePlayer", player, [target.uid, target.name, true]);
        info("Ignoring " + target.name + ". /unignore " + target.name + " to undo");
        return "";
    }

    function ignoreList():String {
        var names = [for (e in ignored()) e.name];
        info(names.length == 0 ? "You are not ignoring anyone." : "Ignored players: " + names.join(", "));
        return "";
    }

    // Searched in the ignore list itself: ignored players' messages are hidden, so the address book may not know them.
    function unignore(name:String):String {
        var key = name.toLowerCase();
        var matches = [for (e in ignored()) if (e.name != null && e.name.toLowerCase() == key) e];
        if (matches.length == 0) return error(name + " is not on your ignore list");
        for (e in matches) G.call("st.Player", "ignorePlayer", player, [e.uid, null, false]);
        info(matches.length == 1 ? "No longer ignoring " + matches[0].name : "No longer ignoring " + matches.length + " players named " + matches[0].name);
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
        if (G.call("st.FriendList", "isFriend", friends, [target.uid]) == true) return error(target.name + " is already your friend");
        var targetName = target.name;
        var reason = G.call("st.FriendList", "addFriend", friends, [target.uid, (ok:Bool) -> if (!ok) ChatPlus.addSystemMessage("Friend request to " + targetName + " failed", true, true, null, true)]);
        if (Type.enumConstructor(reason) != "Ok") return error(G.staticCall("HText", "reason", [reason]));
        info("Friend request sent to " + targetName);
        return "";
    }

    function leave():String {
        var group = G.field(player, "group");
        if (group == null || G.call("st.Group", "get_isSolo", group) == true) return error("You are not in a group");
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
                error("No player " + text + ". Type " + command + " " + query.name + " to list the players of that name");
                return null;
            }
            return list[query.pick - 1];
        }
        var live = LivePlayers.read(player);
        ChatPlus.remember(live.onMap.concat(live.group).concat(live.friends));
        var self:String = G.field(player, "uid");
        var found = PlayerLookup.candidates(query.name, live.onMap, live.group, live.friends, ChatPlus.book, self);
        if (found.length == 0) {
            error("Unknown player " + query.name + ": only players you have seen on your map, in your group, in your friend list or in chat can be found");
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
        info(found.length + " players named " + name + (actOnFirst ? ", using 1:" : ", pick one:"));
        for (i in 0...found.length) {
            var s = found[i];
            ChatPlus.addSystemMessage((i + 1) + ") " + s.name + " - " + PlayerLookup.describe(s, now), true, false, {name: s.name, uid: s.uid});
        }
        var hint = actOnFirst ? "Pick another: " + command + " " + name + ":2" : "Pick: " + command + " " + name + ":1";
        if (!actOnFirst && command == "/w") hint += " (sends your message)";
        ChatPlus.addSystemMessage(hint + ", or right-click a line", true, false);
    }

    function error(text:String):String {
        G.call("ui.hud.ChatBox", "chatError", chat, [NoteFormat.PREFIX + text]);
        return "";
    }

    function info(text:String):Void {
        ChatPlus.addSystemMessage(text, true);
    }
}
