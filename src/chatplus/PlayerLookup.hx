package chatplus;

import chatplus.PlayerBook;

/// A name typed in a command: `Senix`, or `Senix:2` for the second player of the last list for that name.
/// `:` can't occur in character names (`HText.isFormatNameValid`).
typedef NameQuery = {name:String, ?pick:Int};

/// Picks the player meant by a name. Names are not unique, so all accounts with that name are
/// candidates, in this order: on the current map, in the group, friends, then the address book newest first.
class PlayerLookup {
    public static function parseQuery(text:String):NameQuery {
        var colon = text.lastIndexOf(":");

        if (colon > 0) {
            var n = Std.parseInt(text.substr(colon + 1));
            if (n != null && n > 0 && Std.string(n) == text.substr(colon + 1)) {
                return {name: text.substr(0, colon), pick: n};
            }
        }

        return {name: text};
    }

    /// One entry per account, best first. `selfUid` is left out.
    public static function candidates(name:String, onMap:Array<Sighting>, group:Array<Sighting>, friends:Array<Sighting>, book:PlayerBook,
            selfUid:Null<String>):Array<Sighting> {
        var key = name.toLowerCase();
        var result:Array<Sighting> = [];
        function add(list:Array<Sighting>) {
            for (s in list) {
                if (s.name == null || s.uid == null || s.uid == selfUid || s.name.toLowerCase() != key) {
                    continue;
                }
                if (Lambda.exists(result, r -> r.uid == s.uid)) {
                    continue;
                }
                result.push(s);
            }
        }
        add(onMap);
        add(group);
        add(friends);
        add(book.named(name));
        return result;
    }

    /// `Rogue, level 28, on your map` or `whispered with you (21:14)`. `now` is the wall clock in ms.
    public static function describe(s:Sighting, now:Float):String {
        var parts:Array<String> = [];
        if (s.className != null && s.className != "") {
            parts.push(s.className);
        }

        if (s.level != null && s.level > 0) {
            parts.push(Texts.get("describe.level", [s.level]));
        }

        parts.push(switch (s.source) {
            case OnMap: Texts.get(s.live == true ? "describe.onMap" : "describe.wasOnMap");
            case InGroup: Texts.get(s.live == true ? "describe.inGroup" : "describe.wasInGroup");
            case Friend: Texts.get(s.online == null ? "describe.friend" : (s.online ? "describe.friendOnline" : "describe.friendOffline"));
            case Chat: chatText(s.channel);
        });
        var text = parts.join(", ");
        if (s.live != true) {
            text += " (" + seenAt(s.seen, now) + ")";
        }

        return text;
    }

    static function chatText(channel:Null<String>):String {
        return switch (channel) {
            case "whisper": Texts.get("describe.whisper");
            case "group": Texts.get("describe.groupChat");
            case "all": Texts.get("describe.allChat");
            case "local": Texts.get("describe.localChat");
            default: Texts.get("describe.chat");
        }
    }

    /// `21:14` today, `20.11. 21:14` on another day.
    public static function seenAt(time:Float, now:Float):String {
        var date = Date.fromTime(time);
        var today = DateTools.format(Date.fromTime(now), "%Y-%m-%d") == DateTools.format(date, "%Y-%m-%d");

        return (today ? "" : DateTools.format(date, "%d.%m. ")) + DateTools.format(date, "%H:%M");
    }
}
