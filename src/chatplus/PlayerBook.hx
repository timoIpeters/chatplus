package chatplus;

import haxe.Json;

/// Where a player was seen.
enum abstract Source(String) to String {
    var OnMap = "map";
    var InGroup = "group";
    var Friend = "friend";
    var Chat = "chat";
}

/// One player seen under one name. `channel` is set for chat sightings (whisper, group, all, local),
/// `online` for friends. `live` marks players present right now; it is not stored.
typedef Sighting = {
    name:String,
    uid:String,
    seen:Float,
    source:Source,
    ?className:String,
    ?level:Int,
    ?channel:String,
    ?online:Bool,
    ?live:Bool,
}

/// Name → account uid pairs of the players the client has seen, newest first when looked up.
/// One name can belong to several accounts (names are not unique) and one account to several names.
class PlayerBook {
    public final limit:Int;
    var entries:Array<Sighting> = [];

    public function new(limit = 1000) {
        this.limit = limit;
    }

    public var length(get, never):Int;

    function get_length():Int {
        return entries.length;
    }

    /// Adds or updates the entry for this name and uid. Class and level stay when the new sighting has none.
    public function record(s:Sighting):Void {
        if (s.name == null || s.uid == null || s.name == "") return;
        var key = s.name.toLowerCase();
        var old = null;
        for (e in entries) if (e.uid == s.uid && e.name.toLowerCase() == key) old = e;
        if (old != null) {
            if (s.seen < old.seen) return;
            entries.remove(old);
            if (s.className == null) s.className = old.className;
            if (s.level == null) s.level = old.level;
        }
        entries.push(stored(s));
        if (entries.length > limit) {
            entries.sort((a, b) -> a.seen < b.seen ? -1 : (a.seen > b.seen ? 1 : 0));
            entries.splice(0, entries.length - limit);
        }
    }

    /// Entries with this name, ignoring case, newest first.
    public function named(name:String):Array<Sighting> {
        var key = name.toLowerCase();
        var found = [for (e in entries) if (e.name.toLowerCase() == key) e];
        found.sort((a, b) -> a.seen > b.seen ? -1 : (a.seen < b.seen ? 1 : 0));
        return found;
    }

    public function toJson():String {
        return Json.stringify(entries);
    }

    /// Book from `toJson` output. Invalid entries are skipped; invalid JSON throws.
    public static function fromJson(json:String, limit = 1000):PlayerBook {
        var book = new PlayerBook(limit);
        var data:Array<Dynamic> = Json.parse(json);
        if (!Std.isOfType(data, Array)) throw "players file is not a list";
        for (d in data) {
            if (!Std.isOfType(d.name, String) || !Std.isOfType(d.uid, String) || !Std.isOfType(d.seen, Float)) continue;
            var s:Sighting = {name: d.name, uid: d.uid, seen: d.seen, source: sourceOf(d.source)};
            if (Std.isOfType(d.className, String)) s.className = d.className;
            if (Std.isOfType(d.level, Int)) s.level = d.level;
            if (Std.isOfType(d.channel, String)) s.channel = d.channel;
            book.record(s);
        }
        return book;
    }

    static function sourceOf(value:Dynamic):Source {
        return switch (Std.string(value)) {
            case "map": OnMap;
            case "group": InGroup;
            case "friend": Friend;
            default: Chat;
        }
    }

    // Copy without the fields that describe the present moment.
    static function stored(s:Sighting):Sighting {
        var c:Sighting = {name: s.name, uid: s.uid, seen: s.seen, source: s.source};
        if (s.className != null) c.className = s.className;
        if (s.level != null) c.level = s.level;
        if (s.channel != null) c.channel = s.channel;
        return c;
    }
}
