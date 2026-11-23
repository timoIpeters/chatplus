package chatplus;

import chatplus.ModCommands;

/// What happens to a chat command.
enum Route {
    /// No owner: the game gets it.
    Pass;
    Run(owner:Owner);
    /// Several owners: list them and wait for `/name:N`.
    Ask(owners:Array<Owner>);
    /// `/name:N` with no N-th owner.
    NoPick(count:Int);
}

/// Picks a command's owner and builds `/help`.
class CommandRouter {
    /// The owners of `name`. Only the first `PassOn` owner is kept, as later ones can't be reached.
    public static function ownersOf(name:String, all:Array<Owner>):Array<Owner> {
        var result:Array<Owner> = [];
        var passOn = false;
        for (o in all) {
            if (!Lambda.exists(o.commands, c -> c.names.indexOf(name) >= 0)) continue;
            if (o.kind == PassOn) {
                if (passOn) continue;
                passOn = true;
            }
            result.push(o);
        }
        return result;
    }

    /// `name` in lower case. `pick` is the N of `/name:N`.
    public static function route(name:String, pick:Null<Int>, all:Array<Owner>, firstMatch:Bool):Route {
        var owners = ownersOf(name, all);
        if (pick != null) return pick <= owners.length ? Run(owners[pick - 1]) : NoPick(owners.length);
        if (owners.length == 0) return Pass;
        return owners.length == 1 || firstMatch ? Run(owners[0]) : Ask(owners);
    }

    /// The `/help` lines in owner order, with a heading per owner if `grouped`.
    /// Shared commands end with their pick, e.g. ` [/roll:2]`.
    public static function help(all:Array<Owner>, grouped:Bool):Array<String> {
        var lines = [Texts.get("help.title")];
        for (o in all) {
            if (o.commands.length == 0) continue;
            if (grouped) lines.push(NoteFormat.HEADING + o.name);
            for (c in o.commands) {
                var line = c.line;
                if (!grouped && o.kind != Own && o.id != "") line += " (" + o.name + ")";
                lines.push(line + pickMark(o, c, all));
            }
        }
        return lines;
    }

    static function pickMark(owner:Owner, command:CommandHelp, all:Array<Owner>):String {
        for (name in command.names) {
            var owners = ownersOf(name, all);
            var index = owners.indexOf(owner);
            if (owners.length > 1 && index >= 0) return Texts.get("help.pick", [name, index + 1]);
        }
        return "";
    }
}
