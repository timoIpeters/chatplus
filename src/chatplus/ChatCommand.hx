package chatplus;

/// A chat command handled by the mod.
enum ChatCommand {
    /// `/w <name> [message]`: switch to a whisper channel with the player, and send the message if there is one.
    Whisper(name:String, message:String);
    Invite(name:String);
    Leave;
    Ignore(name:String);
    /// `/ignore` without a name: list the ignored players.
    IgnoreList;
    Unignore(name:String);
    Friend(name:String);
    /// `/clear`: remove all chat messages, also from the history they are rebuilt from.
    Clear;
    Help;
    /// `/chatplus`: check the game elements the mod uses.
    Check;
    /// A mod command used wrongly; the text says how to use it.
    Usage(text:String);
}

class ChatCommands {
    static final HELP_KEYS = ["help.title", "help.all", "help.group", "help.local", "help.reply", "help.tab", "help.whisper", "help.invite",
        "help.leave", "help.ignore", "help.unignore", "help.friend", "help.clear", "help.chatplus", "help.help"];

    /// Lines shown by `/help`, in the current language.
    public static function help():Array<String> {
        return [for (key in HELP_KEYS) Texts.get(key)];
    }

    /// The mod's command for `/command args...`, or null when the game should handle it.
    public static function parse(command:String, args:Array<String>):Null<ChatCommand> {
        var words = [for (a in args) if (a != "") a];
        return switch (command.toLowerCase()) {
            case "w", "whisper", "tell":
                words.length == 0 ? Usage(Texts.get("usage.w")) : Whisper(words[0], words.slice(1).join(" "));
            case "invite", "inv":
                words.length == 0 ? Usage(Texts.get("usage.invite")) : Invite(words[0]);
            case "leave":
                Leave;
            case "ignore":
                words.length == 0 ? IgnoreList : Ignore(words[0]);
            case "unignore":
                words.length == 0 ? Usage(Texts.get("usage.unignore")) : Unignore(words[0]);
            case "clear":
                Clear;
            case "friend", "addfriend":
                words.length == 0 ? Usage(Texts.get("usage.friend")) : Friend(words[0]);
            case "help", "?":
                Help;
            case "chatplus":
                Check;
            default:
                null;
        }
    }
}
