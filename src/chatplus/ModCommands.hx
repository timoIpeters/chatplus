package chatplus;

/// A `/help` line and the command names it covers (lower case, without `/`).
/// `topic`: the bus topic of another mod's command.
typedef CommandHelp = {names:Array<String>, line:String, ?topic:String};

/// How a command reaches its owner.
enum OwnerKind {
    /// Chat Plus runs it.
    Own;
    /// Chat Plus publishes the command on the HLX bus (`ModCommands.topic`).
    Published;
    /// The next hook or the game gets it.
    PassOn;
}

/// An owner of chat commands. `id` is the mod's registry id, `""` for the game.
typedef Owner = {id:String, name:String, kind:OwnerKind, commands:Array<CommandHelp>};
typedef HelpKey = {key:String, names:Array<String>};

/// Chat commands of the game, Chat Plus and other mods. Other mods follow the HLX Core convention: they register
/// `{id, name, ?description, commands: [{name, ?description}]}` in the registry bucket `mods` and subscribe to
/// `command.execute.<id>.<name>` on the bus. Chat Plus extras per command: `aliases`, `usage` and `descriptions`.
class ModCommands {
    public static inline var BUCKET = "mods";
    public static inline var SELF = "chat-plus";
    static inline var TOPIC = "command.execute.";

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

    /// All owners by id A-Z (ignoring case), the game last.
    public static function all(entries:Array<Dynamic>):Array<Owner> {
        var owners = [own()];

        for (e in entries) {
            var owner = fromEntry(e);
            if (owner != null) {
                owners.push(owner);
            }
        }

        owners.sort((a, b) -> Reflect.compare(a.id.toLowerCase(), b.id.toLowerCase()));
        owners.push(game());

        return owners;
    }

    /// The owner in a registry entry, or null for Chat Plus's own entry and for entries without `id` or malformed.
    public static function fromEntry(entry:Dynamic):Null<Owner> {
        try {
            var id = text(Reflect.field(entry, "id"));
            if (id == null || id == "" || id == SELF) {
                return null;
            }

            var name = text(Reflect.field(entry, "name"));
            var commands:Array<CommandHelp> = [];

            for (c in items(Reflect.field(entry, "commands"))) {
                var main = text(Reflect.field(c, "name"));
                if (main == null || main == "") {
                    continue;
                }

                var names = [main.toLowerCase()].concat([for (n in items(Reflect.field(c, "aliases"))) text(n).toLowerCase()]);
                var usage = text(Reflect.field(c, "usage"));
                if (usage == null) {
                    usage = "/" + names.join(", /");
                }

                var texts = Reflect.field(c, "descriptions");
                var description = texts == null ? null : text(Reflect.field(texts, Texts.lang));
                if (description == null) {
                    description = text(Reflect.field(c, "description"));
                }

                commands.push({names: names, line: description == null ? usage : usage + " - " + description, topic: TOPIC + id + "." + main});
            }

            return {id: id, name: name == null ? id : name, kind: Published, commands: commands};
        } catch (_:Dynamic) {
            return null;
        }
    }

    /// The bus topic of `owner`'s command `name` (name or alias), or null if `owner` has no such command.
    public static function topic(owner:Owner, name:String):Null<String> {
        for (c in owner.commands) {
            if (c.names.indexOf(name) >= 0) {
                return c.topic;
            }
        }

        return null;
    }

    static function helpLines(keys:Array<HelpKey>):Array<CommandHelp> {
        return [for (k in keys) {names: k.names, line: Texts.get(k.key)}];
    }

    static function text(value:Dynamic):Null<String> {
        return value == null ? null : Std.string(value);
    }

    // Another mod's arrays can only be read as `hl.types.ArrayBase`.
    static function items(value:Dynamic):Array<Dynamic> {
        if (value == null) {
            return [];
        }

        #if hl
        // An `Array<Dynamic>` is an `ArrayDyn`, which wraps an `ArrayBase` in `array`.
        var inner:Dynamic = Reflect.field(value, "array");
        var array:hl.types.ArrayBase = Std.isOfType(inner, hl.types.ArrayBase) ? inner : value;
        return [for (i in 0...array.length) array.getDyn(i)];
        #else
        return value;
        #end
    }
}
