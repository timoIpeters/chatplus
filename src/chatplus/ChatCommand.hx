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
    /// Lines shown by `/help`.
    public static final HELP = [
        "Chat commands:",
        "/all, /map <msg> - All channel",
        "/p, /party, /gr, /group <msg> - Group channel",
        "/s, /say <msg> - Local channel",
        "/r <msg> - reply to the last whisper",
        "Tab, Shift+Tab - switch channel while typing",
        "/w, /whisper, /tell <name> [msg] - whisper to a player",
        "/invite, /inv <name> - invite a player to your group",
        "/leave - leave your group",
        "/ignore <name> - ignore a player; /ignore lists the ignored players",
        "/unignore <name> - stop ignoring a player",
        "/friend <name> - send a friend request",
        "/clear - remove chat messages (what is removed: Mod Settings)",
        "/chatplus - check that the game still has everything the mod uses",
        "/help - this list",
    ];

    /// The mod's command for `/command args...`, or null when the game should handle it.
    public static function parse(command:String, args:Array<String>):Null<ChatCommand> {
        var words = [for (a in args) if (a != "") a];
        return switch (command.toLowerCase()) {
            case "w", "whisper", "tell":
                words.length == 0 ? Usage("Usage: /w <name> [message]") : Whisper(words[0], words.slice(1).join(" "));
            case "invite", "inv":
                words.length == 0 ? Usage("Usage: /invite <name>") : Invite(words[0]);
            case "leave":
                Leave;
            case "ignore":
                words.length == 0 ? IgnoreList : Ignore(words[0]);
            case "unignore":
                words.length == 0 ? Usage("Usage: /unignore <name>") : Unignore(words[0]);
            case "clear":
                Clear;
            case "friend", "addfriend":
                words.length == 0 ? Usage("Usage: /friend <name>") : Friend(words[0]);
            case "help", "?":
                Help;
            case "chatplus":
                Check;
            default:
                null;
        }
    }
}
