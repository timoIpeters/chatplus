package chatplus;

/// A `/help` line and the command names it covers (lower case, without `/`).
typedef CommandHelp = {names:Array<String>, line:String};

/// How a command reaches its owner.
enum OwnerKind {
    /// Chat Plus runs it.
    Own;
    /// Chat Plus calls the mod's `run(chat, command, args)`.
    Handler(run:Dynamic);
    /// The next hook or the game gets it.
    PassOn;
}

/// An owner of chat commands. `id` is the mod folder, `""` for the game.
typedef Owner = {id:String, name:String, kind:OwnerKind, commands:Array<CommandHelp>};

typedef HelpKey = {key:String, names:Array<String>};

/// Chat commands of the game, Chat Plus and other mods. Other mods register theirs in the registry bucket
/// `chat-commands` as `{id, mod, commands: [{names, usage, text, ?texts}], ?run}`.
class ModCommands {
    public static inline var BUCKET = "chat-commands";
    public static inline var SELF = "chat-plus";

    static final GAME:Array<HelpKey> = [
        {key: "help.all", names: ["all", "map"]},
        {key: "help.group", names: ["p", "party", "gr", "group"]},
        {key: "help.local", names: ["s", "say"]},
        {key: "help.reply", names: ["r"]},
        {key: "help.tab", names: []},
    ];
    /// Chat Plus's commands.
    public static final OWN:Array<HelpKey> = [
        {key: "help.whisper", names: ["w", "whisper", "tell"]},
        {key: "help.invite", names: ["invite", "inv"]},
        {key: "help.leave", names: ["leave"]},
        {key: "help.ignore", names: ["ignore"]},
        {key: "help.unignore", names: ["unignore"]},
        {key: "help.friend", names: ["friend", "addfriend"]},
        {key: "help.clear", names: ["clear"]},
        {key: "help.chatplus", names: ["chatplus"]},
        {key: "help.help", names: ["help", "?"]},
    ];
    public static function game():Owner {
        return {id: "", name: Texts.get("help.game"), kind: PassOn, commands: helpLines(GAME)};
    }

    public static function own():Owner {
        return {id: SELF, name: "Chat Plus", kind: Own, commands: helpLines(OWN)};
    }

    /// All owners in hook order: mod folders A-Z, the game last.
    public static function all(entries:Array<Dynamic>):Array<Owner> {
        var owners = [own()];
        for (e in entries) {
            var owner = fromEntry(e);
            if (owner != null) owners.push(owner);
        }
        owners.sort((a, b) -> Reflect.compare(a.id, b.id));
        owners.push(game());
        return owners;
    }

    /// The owner in a registry entry, or null for Chat Plus's own and malformed entries.
    public static function fromEntry(entry:Dynamic):Null<Owner> {
        try {
            var id = text(Reflect.field(entry, "id"));
            if (id == null || id == SELF) return null;
            var name = text(Reflect.field(entry, "mod"));
            var run = Reflect.field(entry, "run");
            var commands:Array<CommandHelp> = [];
            for (c in items(Reflect.field(entry, "commands"))) {
                var names = [for (n in items(Reflect.field(c, "names"))) text(n).toLowerCase()];
                var usage = text(Reflect.field(c, "usage"));
                if (names.length == 0 || usage == null) continue;
                var texts = Reflect.field(c, "texts");
                var description = texts == null ? null : text(Reflect.field(texts, Texts.lang));
                if (description == null) description = text(Reflect.field(c, "text"));
                commands.push({names: names, line: description == null ? usage : usage + " - " + description});
            }
            return {id: id, name: name == null ? id : name, kind: run == null ? PassOn : Handler(run), commands: commands};
        } catch (_:Dynamic) {
            return null;
        }
    }

    static function helpLines(keys:Array<HelpKey>):Array<CommandHelp> {
        return [for (k in keys) {names: k.names, line: Texts.get(k.key)}];
    }

    static function text(value:Dynamic):Null<String> {
        return value == null ? null : Std.string(value);
    }

    // Another mod's arrays can only be read as `hl.types.ArrayBase`.
    static function items(value:Dynamic):Array<Dynamic> {
        if (value == null) return [];
        #if hl
        var array:hl.types.ArrayBase = value;
        return [for (i in 0...array.length) array.getDyn(i)];
        #else
        return value;
        #end
    }
}
