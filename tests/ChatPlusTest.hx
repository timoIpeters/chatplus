import chatplus.ChatCommand;
import chatplus.ChatTime;
import chatplus.NoteFormat;
import chatplus.PlayerNames;
import chatplus.Settings;

class ChatPlusTest {
    static var failures = 0;

    static function main():Void {
        chatTime();
        settings();
        commands();
        playerNames();
        noteFormat();
        if (failures > 0) {
            Sys.println(failures + " check(s) failed");
            Sys.exit(1);
        }
        Sys.println("All checks passed");
    }

    static function chatTime():Void {
        var now = new Date(2026, 10, 21, 14, 30, 20).getTime();
        check("same moment", ChatTime.format(500, 500, now), "14:30");
        check("90 s earlier", ChatTime.format(410, 500, now), "14:28");
        check("leading zero", ChatTime.format(0, 0, new Date(2026, 0, 1, 7, 5, 0).getTime()), "07:05");
    }

    static function settings():Void {
        var d = new Settings();
        check("default timestamps", d.timestamps, true);
        check("default keepHistory", d.keepHistory, true);
        check("default historyLimit", d.historyLimit, 500);
        check("default switchMessage", d.switchMessage, false);
        check("parsed switchMessage", Settings.parse('{"switchMessage": true}').switchMessage, true);

        var s = Settings.parse('{"timestamps": false, "historyLimit": 50}');
        check("parsed timestamps", s.timestamps, false);
        check("missing key keeps default", s.keepHistory, true);
        check("parsed historyLimit", s.historyLimit, 50);

        var bad = Settings.parse('{"timestamps": "no", "historyLimit": -3}');
        check("wrong type keeps default", bad.timestamps, true);
        check("invalid limit keeps default", bad.historyLimit, 500);

        var round = Settings.parse(s.toJson());
        check("round trip", round.timestamps + "," + round.keepHistory + "," + round.switchMessage + "," + round.historyLimit, "false,true,false,50");

        var threw = false;
        try Settings.parse("{") catch (_:Dynamic) threw = true;
        check("invalid JSON throws", threw, true);
    }

    static function commands():Void {
        check("whisper", Std.string(ChatCommands.parse("w", ["Anna", "hi", "there"])), "Whisper(Anna,hi there)");
        check("whisper without message", Std.string(ChatCommands.parse("tell", ["Anna"])), "Whisper(Anna,)");
        check("whisper alias, upper case", Std.string(ChatCommands.parse("WHISPER", ["Anna", "x"])), "Whisper(Anna,x)");
        check("double spaces", Std.string(ChatCommands.parse("w", ["", "Anna", "", "hi"])), "Whisper(Anna,hi)");
        check("whisper without name", Std.string(ChatCommands.parse("w", [])), "Usage(Usage: /w <name> [message])");
        check("invite", Std.string(ChatCommands.parse("invite", ["Bob"])), "Invite(Bob)");
        check("inv alias", Std.string(ChatCommands.parse("inv", ["Bob", "extra"])), "Invite(Bob)");
        check("invite without name", Std.string(ChatCommands.parse("invite", [""])), "Usage(Usage: /invite <name>)");
        check("leave", Std.string(ChatCommands.parse("leave", [])), "Leave");
        check("help", Std.string(ChatCommands.parse("help", [])), "Help");
        check("game command stays with the game", ChatCommands.parse("p", ["hi"]), null);
        check("unknown command stays with the game", ChatCommands.parse("dance", []), null);
    }

    static function playerNames():Void {
        var known = [{name: "Anna", uid: "1"}, {name: "anna", uid: "2"}, {name: null, uid: "3"}, {name: "Bob", uid: null}, {name: "Cleo", uid: "4"}];
        check("exact name", PlayerNames.find(known, "Cleo").uid, "4");
        check("ignores case, first wins", PlayerNames.find(known, "ANNA").uid, "1");
        check("entry without uid skipped", PlayerNames.find(known, "Bob"), null);
        check("unknown name", PlayerNames.find(known, "Dora"), null);
    }

    static function noteFormat():Void {
        check("single line", NoteFormat.toMarkup("Group invite sent to <Anna>"),
            '<font color="#FF9933">[Chat Plus] Group invite sent to &lt;Anna&gt;</font>');
        check("help", NoteFormat.toMarkup("Chat commands:\n/w <name> - whisper\nno command - here"),
            '<font color="#FF9933">[Chat Plus] Chat commands:</font><br/>'
            + '<font color="#8CC8FF">/w &lt;name&gt;</font><font color="#FF9933"> - whisper</font><br/>'
            + '<font color="#FF9933">no command - here</font>');
        check("command without description", NoteFormat.toMarkup("x\n/leave"),
            '<font color="#FF9933">[Chat Plus] x</font><br/><font color="#FF9933">/leave</font>');
    }

    static function check(name:String, actual:Dynamic, expected:Dynamic):Void {
        if (actual == expected) return;
        failures++;
        Sys.println('FAIL $name: expected $expected, got $actual');
    }
}
