package chatplus;

typedef KnownPlayer = {name:String, uid:String};

/// Finds a player's uid by name among the players the client knows (current map, friends, chat).
class PlayerNames {
    /// The first player whose name equals `name`, ignoring case, or null. `players` is in order of preference.
    public static function find(players:Array<KnownPlayer>, name:String):Null<KnownPlayer> {
        var wanted = name.toLowerCase();
        for (p in players) if (p.name != null && p.uid != null && p.name.toLowerCase() == wanted) return p;
        return null;
    }
}
