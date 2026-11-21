package chatplus;

import chatplus.PlayerBook;
import chatplus.Game as G;

/// Players the client knows right now, read from the game as address book sightings.
class LivePlayers {
    // st.Channel constructor indexes.
    static inline var CHANNEL_LOCAL = 0;
    static inline var CHANNEL_ALL = 1;
    static inline var CHANNEL_WHISPER = 3;
    static inline var CHANNEL_GROUP = 4;

    /// Players on the current map, group members (also on other maps) and friends of `player` (`st.Player`).
    public static function read(player:Dynamic):{onMap:Array<Sighting>, group:Array<Sighting>, friends:Array<Sighting>} {
        var now = Date.now().getTime();
        var onMap = [for (p in G.elements(G.field(G.field(player, "layer"), "players"))) ofPlayer(p, OnMap, now)];
        var group = [for (p in G.elements(G.field(G.field(player, "group"), "players"))) ofPlayer(p, InGroup, now)];
        var friends = [for (f in G.elements(G.field(G.field(player, "friendList"), "friends"))) ofFriend(f, now)];
        return {onMap: onMap, group: group, friends: friends};
    }

    /// The sender of a chat message and, for whispers, the partner named in the channel.
    public static function fromMessage(message:Dynamic, now:Float):Array<Sighting> {
        var result:Array<Sighting> = [];
        var channel = G.field(message, "channel");
        if (channel == null) return result;
        var name = switch (Type.enumIndex(channel)) {
            case CHANNEL_LOCAL: "local";
            case CHANNEL_ALL: "all";
            case CHANNEL_WHISPER: "whisper";
            case CHANNEL_GROUP: "group";
            default: return result;
        }
        var sender = G.field(message, "sender");
        if (sender != null) result.push({name: G.field(sender, "name"), uid: G.field(sender, "uid"), seen: now, source: Chat, channel: name});
        if (Type.enumIndex(channel) == CHANNEL_WHISPER) {
            var params = Type.enumParameters(channel);
            result.push({name: params[1], uid: params[0], seen: now, source: Chat, channel: name});
        }
        var self = selfUid();
        return [for (s in result) if (s.uid != self) s];
    }

    public static function selfUid():Null<String> {
        var get = G.staticField("GameApp", "get");
        var app = get == null ? null : Reflect.callMethod(null, get, []);
        return G.field(G.field(G.field(app, "hero"), "player"), "uid");
    }

    static function ofPlayer(p:Dynamic, source:Source, now:Float):Sighting {
        var hero = G.field(p, "heroData");
        return {
            name: G.call("st.Player", "getName", p),
            uid: G.field(p, "uid"),
            seen: now,
            source: source,
            className: className(G.field(hero, "kind")),
            level: G.field(hero, "level"),
            live: true,
        };
    }

    static function ofFriend(f:Dynamic, now:Float):Sighting {
        var meta = G.field(f, "metadata");
        return {
            name: G.field(meta, "heroName"),
            uid: G.field(f, "uid"),
            seen: now,
            source: Friend,
            className: className(G.field(meta, "kind")),
            level: G.field(meta, "level"),
            online: G.field(meta, "connected") == true,
            live: true,
        };
    }

    // Display name of a class unit id (e.g. the Rogue unit), without markup.
    static function className(kind:Dynamic):Null<String> {
        if (kind == null) return null;
        try {
            var text:String = G.staticCall("HText", "unitById", [kind, null]);
            return text == null ? null : ~/<[^>]*>/g.replace(text, "");
        } catch (_:Dynamic) return null;
    }
}
