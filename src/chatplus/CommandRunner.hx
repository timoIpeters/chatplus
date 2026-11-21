package chatplus;

import chatplus.ChatCommand;
import chatplus.PlayerNames.KnownPlayer;
import chatplus.Game as G;

/// Runs the mod's chat commands against the game. Each function returns what `ChatBox.handleCommand`
/// returns: the text to send to the selected channel, or "" when nothing is sent.
class CommandRunner {
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
        var target = find(name);
        if (target == null) return unknownPlayer(name);
        var channelType = HlxRuntime.resolveType("st.Channel");
        if (channelType == null) throw "Game type unavailable: st.Channel";
        // Same channel as "Send message" in the player menu: it is added to the dropdown and selected.
        var channel = HlxRuntime.constructEnum(channelType, "Player", [target.uid, target.name]);
        G.call("ui.hud.ChatBox", "setChannel", chat, [channel]);
        return message;
    }

    // Same calls as "Invite to group" in the player menu (GameUI.openPlayerInteractionMenu).
    function invite(name:String):String {
        var target = find(name);
        if (target == null) return unknownPlayer(name);
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

    function find(name:String):Null<KnownPlayer> {
        var self:String = G.field(player, "uid");
        var known = [for (p in knownPlayers()) if (p.uid != self) p];
        return PlayerNames.find(known, name);
    }

    // Players on the current map first, then friends, then senders and whisper partners from the chat, newest first.
    function knownPlayers():Array<KnownPlayer> {
        var list:Array<KnownPlayer> = [];
        for (p in G.elements(G.field(G.field(player, "layer"), "players")))
            list.push({name: G.call("st.Player", "getName", p), uid: G.field(p, "uid")});
        for (f in G.elements(G.field(G.field(player, "friendList"), "friends")))
            list.push({name: G.field(G.field(f, "metadata"), "heroName"), uid: G.field(f, "uid")});
        var history = G.elements(G.staticField("st.player.ChatClient", "history"));
        history.reverse();
        for (m in history) {
            var sender = G.field(m, "sender");
            if (sender != null) list.push({name: G.field(sender, "name"), uid: G.field(sender, "uid")});
            var channel = G.field(m, "channel");
            if (channel != null && Type.enumConstructor(channel) == "Player") {
                var params = Type.enumParameters(channel);
                list.push({name: params[1], uid: params[0]});
            }
        }
        return list;
    }

    function unknownPlayer(name:String):String {
        return error("Unknown player " + name + ": only players on your map, friends and players from your chat can be found");
    }

    function error(text:String):String {
        G.call("ui.hud.ChatBox", "chatError", chat, [NoteFormat.PREFIX + text]);
        return "";
    }

    function info(text:String):Void {
        ChatPlus.addSystemMessage(text, true);
    }
}
