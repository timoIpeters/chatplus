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

    final chat:Dynamic;
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
            case Help:
                info(ChatCommands.HELP.join("\n"));
                "";
            case Usage(text): error(text);
        }
    }

    function whisper(name:String, message:String):String {
        var target = find(name, "/w");
        if (target == null) return "";
        var channelType = HlxRuntime.resolveType("st.Channel");
        if (channelType == null) throw "Game type unavailable: st.Channel";
        // Same channel as "Send message" in the player menu: it is added to the dropdown and selected.
        var channel = HlxRuntime.constructEnum(channelType, "Player", [target.uid, target.name]);
        G.call("ui.hud.ChatBox", "setChannel", chat, [channel]);
        return message;
    }

    // Same calls as "Invite to group" in the player menu (GameUI.openPlayerInteractionMenu).
    function invite(name:String):String {
        var target = find(name, "/invite");
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

    function leave():String {
        var group = G.field(player, "group");
        if (group == null || G.call("st.Group", "get_isSolo", group) == true) return error("You are not in a group");
        G.call("st.Player", "leaveGroup", player);
        return "";
    }

    /// The player meant by `text` (`Name` or `Name:N`), or null after showing an error. With several
    /// accounts of that name it takes the first and lists all, each line right-clickable.
    function find(text:String, command:String):Null<Sighting> {
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
        if (found.length > 1) showChoices(query.name, found, command);
        return found[0];
    }

    function showChoices(name:String, found:Array<Sighting>, command:String):Void {
        lastLists.set(name.toLowerCase(), found);
        var now = Date.now().getTime();
        info(found.length + " players named " + name + ", using 1:");
        for (i in 0...found.length) {
            var s = found[i];
            ChatPlus.addSystemMessage((i + 1) + ") " + s.name + " - " + PlayerLookup.describe(s, now), true, false, {name: s.name, uid: s.uid});
        }
        ChatPlus.addSystemMessage("Pick another: " + command + " " + name + ":2, or right-click a line", true, false);
    }

    function error(text:String):String {
        G.call("ui.hud.ChatBox", "chatError", chat, [NoteFormat.PREFIX + text]);
        return "";
    }

    function info(text:String):Void {
        ChatPlus.addSystemMessage(text, true);
    }
}
