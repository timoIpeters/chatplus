import chatplus.ChatCommand;
import chatplus.ChatTime;
import chatplus.NoteFormat;
import chatplus.PlayerBook;
import chatplus.PlayerLookup;
import chatplus.Settings;

class ChatPlusTest {
    static var failures = 0;

    static function main():Void {
        chatTime();
        settings();
        commands();
        playerBook();
        playerLookup();
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
        check("default inviteFirstMatch", d.inviteFirstMatch, true);
        check("default rememberClosed", d.rememberClosed, true);
        check("parsed rememberClosed", Settings.parse('{"rememberClosed": false}').rememberClosed, false);
        check("default whisperFirstMatch", d.whisperFirstMatch, false);
        check("parsed whisperFirstMatch", Settings.parse('{"whisperFirstMatch": true}').whisperFirstMatch, true);
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

        var t = Settings.parse('{"timestamps": false}');
        check("get", t.get("timestamps"), false);
        for (toggle in Settings.TOGGLES) check("toggle key is a Bool field: " + toggle.key, Std.isOfType(Reflect.field(new Settings(), toggle.key), Bool), true);
        check("every toggle saved", [for (toggle in Settings.TOGGLES) if (new Settings().toJson().indexOf('"' + toggle.key + '"') < 0) toggle.key].length, 0);

        var formats:Dynamic = haxe.Json.parse(Settings.formatsJson());
        var configs:Array<Dynamic> = formats.configs;
        check("formats: display name", formats.displayName, "Chat Plus");
        check("formats: title first", configs[0].type, "title");
        check("formats: one checkbox per toggle, in order", [for (c in configs) if (c.type == "checkbox") c.key].join(","), [for (t in Settings.TOGGLES) t.key].join(","));
        check("formats: every checkbox has a tooltip", [for (c in configs) if (c.type == "checkbox" && (c.tooltip == null || c.tooltip.tooltipText == "")) c.key].length, 0);
        var slider:Dynamic = [for (c in configs) if (c.type == "slider") c][0];
        check("formats: historyLimit slider", slider.key + " " + slider.min + "-" + slider.max + "/" + slider.step, "historyLimit 100-2000/100");
        check("formats: default limit on the slider grid", (new Settings().historyLimit - slider.min) % slider.step, 0);

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

    static function playerBook():Void {
        var book = new PlayerBook(3);
        book.record({name: "Senix", uid: "A", seen: 10, source: OnMap, className: "Rogue", level: 28});
        book.record({name: "senix", uid: "A", seen: 20, source: Chat, channel: "whisper"});
        check("same name and account: one entry", book.length, 1);
        var a = book.named("SENIX")[0];
        check("newer sighting wins", a.source + "/" + a.channel, "chat/whisper");
        check("class and level kept", a.className + " " + a.level, "Rogue 28");
        book.record({name: "Senix", uid: "A", seen: 5, source: Friend});
        check("older sighting ignored", book.named("Senix")[0].seen, 20.0);

        book.record({name: "Senix", uid: "B", seen: 30, source: Chat});
        book.record({name: "Bran", uid: "A", seen: 15, source: Chat});
        check("one name, two accounts, newest first", [for (s in book.named("Senix")) s.uid].join(","), "B,A");
        check("one account, two names", book.named("Bran")[0].uid, "A");
        book.record({name: "Cleo", uid: "C", seen: 40, source: Chat});
        check("limit drops the oldest", book.named("Bran").length + "/" + book.length, "0/3");
        book.record({name: null, uid: "D", seen: 50, source: Chat});
        book.record({name: "Dora", uid: null, seen: 50, source: Chat});
        check("entries without name or uid ignored", book.length, 3);

        var round = PlayerBook.fromJson(book.toJson(), 3);
        check("round trip", [for (s in round.named("Senix")) s.uid + ":" + s.source].join(","), "B:chat,A:chat");
        check("live is not stored", book.toJson().indexOf("live") == -1, true);
        check("invalid entries skipped", PlayerBook.fromJson('[{"name":"X"},{"name":"Y","uid":"1","seen":1}]').length, 1);
    }

    static function playerLookup():Void {
        check("plain name", PlayerLookup.parseQuery("Senix").name, "Senix");
        check("pick", PlayerLookup.parseQuery("Senix:2").name + "#" + PlayerLookup.parseQuery("Senix:2").pick, "Senix#2");
        check("pick 0 is no pick", PlayerLookup.parseQuery("Senix:0").pick, null);
        check("text after colon is no pick", PlayerLookup.parseQuery("Senix:x").pick, null);

        var book = new PlayerBook();
        book.record({name: "Senix", uid: "old", seen: 1, source: Chat});
        book.record({name: "Senix", uid: "new", seen: 9, source: Chat});
        book.record({name: "Senix", uid: "me", seen: 9, source: Chat});
        var onMap = [{name: "Senix", uid: "map", seen: 0.0, source: OnMap, live: true}];
        var group = [{name: "SENIX", uid: "grp", seen: 0.0, source: InGroup, live: true}, {name: "Senix", uid: "map", seen: 0.0, source: InGroup, live: true}];
        var friends = [{name: "Senix", uid: "new", seen: 0.0, source: Friend, live: true}, {name: "Other", uid: "x", seen: 0.0, source: Friend, live: true}];
        var found = PlayerLookup.candidates("senix", onMap, group, friends, book, "me");
        check("order map, group, friends, book; one per account; self left out",
            [for (s in found) s.uid + ":" + s.source].join(","), "map:map,grp:group,new:friend,old:chat");
        check("no match", PlayerLookup.candidates("Nobody", onMap, group, friends, book, "me").length, 0);

        var now = new Date(2026, 10, 21, 22, 0, 0).getTime();
        var today = new Date(2026, 10, 21, 21, 14, 0).getTime();
        var earlier = new Date(2026, 10, 20, 18, 2, 0).getTime();
        check("live on map", PlayerLookup.describe({name: "S", uid: "1", seen: now, source: OnMap, className: "Rogue", level: 28, live: true}, now), "Rogue, level 28, on your map");
        check("live friend", PlayerLookup.describe({name: "S", uid: "1", seen: now, source: Friend, online: false, live: true}, now), "friend, offline");
        check("whisper today", PlayerLookup.describe({name: "S", uid: "1", seen: today, source: Chat, channel: "whisper"}, now), "whispered with you (21:14)");
        check("group yesterday", PlayerLookup.describe({name: "S", uid: "1", seen: earlier, source: InGroup, level: 12}, now), "level 12, was in your group (20.11. 18:02)");
    }

    static function noteFormat():Void {
        check("single line", NoteFormat.toMarkup("Group invite sent to <Anna>"),
            '<font color="#FF9933">[Chat Plus] Group invite sent to &lt;Anna&gt;</font>');
        check("help", NoteFormat.toMarkup("Chat commands:\n/w <name> - whisper\nno command - here"),
            '<font color="#FF9933">[Chat Plus] Chat commands:</font><br/>'
            + '<font color="#8CC8FF">/w &lt;name&gt;</font><font color="#FF9933"> - whisper</font><br/>'
            + '<font color="#FF9933">no command - here</font>');
        check("key line", NoteFormat.toMarkup("x\nTab - switch", false),
            '<font color="#FF9933">x</font><br/><font color="#8CC8FF">Tab</font><font color="#FF9933"> - switch</font>');
        check("command without description", NoteFormat.toMarkup("x\n/leave"),
            '<font color="#FF9933">[Chat Plus] x</font><br/><font color="#FF9933">/leave</font>');
    }

    static function check(name:String, actual:Dynamic, expected:Dynamic):Void {
        if (actual == expected) return;
        failures++;
        Sys.println('FAIL $name: expected $expected, got $actual');
    }
}
