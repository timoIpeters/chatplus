import chatplus.ChatCommand;
import chatplus.ChatSize;
import chatplus.ChatTime;
import chatplus.ClearFilter;
import chatplus.CommandRouter;
import chatplus.GameCheck;
import chatplus.ModCommands;
import chatplus.NoteFormat;
import chatplus.PlayerBook;
import chatplus.PlayerLookup;
import chatplus.Settings;
import chatplus.Texts;

class ChatPlusTest {
    static var failures = 0;

    static function main():Void {
        chatTime();
        settings();
        commands();
        modCommands();
        playerBook();
        playerLookup();
        noteFormat();
        gameCheck();
        texts();

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
        check("default commandFirstMatch, groupHelp", d.commandFirstMatch && d.groupHelp, true);
        check("default showErrors", d.showErrors, true);
        check("default /clear: all messages, channels kept, no note",
            [d.clearAll, d.clearGroup, d.clearLocal, d.clearWhispers, d.clearSystem, d.clearWhisperChannels, d.clearNote].join(","),
            "true,true,true,true,true,false,false");
        var keepWhispers = Settings.parse('{"clearWhispers": false, "clearSystem": false}');
        check("filter: whispers kept", ClearFilter.removes(3, keepWhispers), false);
        check("filter: group removed", ClearFilter.removes(4, keepWhispers), true);
        check("filter: both system channels kept", ClearFilter.removes(2, keepWhispers) || ClearFilter.removes(5, keepWhispers), false);
        check("filter: local and all removed", ClearFilter.removes(0, keepWhispers) && ClearFilter.removes(1, keepWhispers), true);
        check("default chat size is the game's", d.chatWidth + "x" + d.chatHeight, "480x250");
        var sized = Settings.parse('{"chatWidth": 700, "chatHeight": 100}');
        check("chat size parsed, below the minimum raised", sized.chatWidth + "x" + sized.chatHeight, "700x250");
        var r = ChatSize.dragged(480, 250, 100.4, 50.6, 1000, 600);
        check("drag adds the distance", r.width + "x" + r.height, "580x301");
        r = ChatSize.dragged(600, 300, -500, -500, 1000, 600);
        check("drag stops at the minimum", r.width + "x" + r.height, "480x250");
        r = ChatSize.dragged(600, 300, 900, 900, 1000, 600);
        check("drag stops at the maximum", r.width + "x" + r.height, "1000x600");
        r = ChatSize.dragged(480, 250, 50, 50, 300, 200);
        check("minimum wins over a small screen", r.width + "x" + r.height, "480x250");
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

        check("complete file", Settings.incomplete(new Settings().toJson()), false);
        check("file from an older version", Settings.incomplete('{"timestamps": true, "historyLimit": 500}'), true);
        var round = Settings.parse(s.toJson());
        check("round trip", round.timestamps + "," + round.keepHistory + "," + round.switchMessage + "," + round.historyLimit, "false,true,false,50");

        var t = Settings.parse('{"timestamps": false}');
        check("get", t.get("timestamps"), false);
        for (toggle in Settings.TOGGLES) {
            check("toggle key is a Bool field: " + toggle.key, Std.isOfType(Reflect.field(new Settings(), toggle.key), Bool), true);
        }
        check("every toggle saved", [for (toggle in Settings.TOGGLES) if (new Settings().toJson().indexOf('"' + toggle.key + '"') < 0) toggle.key].length, 0);

        var formats:Dynamic = haxe.Json.parse(Settings.formatsJson());
        var configs:Array<Dynamic> = formats.configs;
        check("formats: display name", formats.displayName, "Chat Plus");
        check("formats: title first", configs[0].type, "title");
        check("formats: sections", [for (c in configs) if (c.type == "title") c.label].join(","),
            "Chat,Character switch,Players & commands,/clear,Chat size,Troubleshooting");
        check("formats: every toggle in a known section",
            [for (t in Settings.TOGGLES) if (!Lambda.exists(Settings.SECTIONS, s -> s.id == t.section)) t.key].join(","), "");
        var afterSwitchTitle = configs.indexOf([for (c in configs) if (c.type == "title" && c.label == "Character switch") c][0]);
        check("formats: history slider under Character switch", configs[afterSwitchTitle + 3].key, "historyLimit");
        check("formats: one checkbox per toggle, in order", [for (c in configs) if (c.type == "checkbox") c.key].join(","),
            [for (t in Settings.TOGGLES) t.key].join(","));
        check("formats: every checkbox has a tooltip",
            [for (c in configs) if (c.type == "checkbox" && (c.tooltip == null || c.tooltip.tooltipText == "")) c.key].length, 0);
        var slider:Dynamic = [for (c in configs) if (c.type == "slider") c][0];
        check("formats: size sliders", [for (c in configs) if (c.type == "slider") c.key].join(","), "historyLimit,chatWidth,chatHeight");
        check("formats: historyLimit slider", slider.key + " " + slider.min + "-" + slider.max + "/" + slider.step, "historyLimit 100-2000/100");
        check("formats: default limit on the slider grid", (new Settings().historyLimit - slider.min) % slider.step, 0);

        var threw = false;
        try {
            Settings.parse("{");
        } catch (_:Dynamic) {
            threw = true;
        }
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
        check("ignore", Std.string(ChatCommands.parse("ignore", ["Bob"])), "Ignore(Bob)");
        check("ignore without name lists", Std.string(ChatCommands.parse("ignore", [])), "IgnoreList");
        check("unignore", Std.string(ChatCommands.parse("unignore", ["Bob"])), "Unignore(Bob)");
        check("unignore without name", Std.string(ChatCommands.parse("unignore", [])), "Usage(Usage: /unignore <name>)");
        check("friend", Std.string(ChatCommands.parse("friend", ["Bob"])), "Friend(Bob)");
        check("clear", Std.string(ChatCommands.parse("clear", [])), "Clear");
        check("addfriend alias", Std.string(ChatCommands.parse("addfriend", ["Bob"])), "Friend(Bob)");
        check("help", Std.string(ChatCommands.parse("help", [])), "Help");
        check("chatplus", Std.string(ChatCommands.parse("chatplus", [])), "Check");
        check("game command stays with the game", ChatCommands.parse("p", ["hi"]), null);
        check("unknown command stays with the game", ChatCommands.parse("dance", []), null);
    }

    static function clashEntry(run:Dynamic):Dynamic {
        return {
            id: "aaa-clash-test",
            mod: "Clash Test",
            run: run,
            commands: [
                {names: ["Roll"], usage: "/roll <max>", text: "test roll", texts: {de: "Testwurf"}},
                {names: ["clear"], usage: "/clear", text: "test clear"},
                {usage: "/nonames"},
            ]
        };
    }

    // A second owner of /roll without `run`.
    static final OTHER_ENTRY:Dynamic = {id: "other-mod", mod: "Other Mod", commands: [{names: ["roll"], usage: "/roll", text: "other roll"}]};

    static function modCommands():Void {
        for (k in ModCommands.OWN) {
            for (n in k.names) {
                check("own help name /" + n + " is parsed", ChatCommands.parse(n, ["x"]) != null, true);
            }
        }

        var run = (chat:Dynamic, command:String, args:Dynamic) -> "sent";
        var entry = ModCommands.fromEntry(clashEntry(run));
        check("entry: names lower case, line with text, entry without names dropped", [for (c in entry.commands) c.names.join("/") + "=" + c.line].join(";"),
            "roll=/roll <max> - test roll;clear=/clear - test clear");
        check("entry with run is a handler", std.Type.enumConstructor(entry.kind), "Handler");
        check("entry without run is handed on", ModCommands.fromEntry(clashEntry(null)).kind, PassOn);
        check("own entry skipped", ModCommands.fromEntry({id: "chat-plus", mod: "Chat Plus"}), null);
        check("malformed entry skipped", ModCommands.fromEntry({id: "x", commands: 5}), null);
        check("entry without id skipped", ModCommands.fromEntry({mod: "x"}), null);

        var all = ModCommands.all([OTHER_ENTRY, clashEntry(run)]);
        check("owners in HLX order, game last", [for (o in all) o.id].join(","), "aaa-clash-test,chat-plus,other-mod,");
        check("owners of /roll", [for (o in CommandRouter.ownersOf("roll", all)) o.id].join(","), "aaa-clash-test,other-mod");
        check("owners of /clear", [for (o in CommandRouter.ownersOf("clear", all)) o.id].join(","), "aaa-clash-test,chat-plus");
        var passOnTwice = ModCommands.all([{id: "zzz", mod: "Z", commands: [{names: ["p"], usage: "/p"}]}]);
        check("only the first handed-on owner is kept", [for (o in CommandRouter.ownersOf("p", passOnTwice)) o.id].join(","), "zzz");

        function route(name:String, pick:Null<Int>, firstMatch:Bool):String {
            return switch (CommandRouter.route(name, pick, all, firstMatch)) {
                case Pass: "Pass";
                case Run(o): "Run " + o.id;
                case Ask(os): "Ask " + [for (o in os) o.id].join(",");
                case NoPick(n): "NoPick " + n;
            }
        }
        check("unknown command goes to the game", route("dance", null, true), "Pass");
        check("single owner runs", route("w", null, false), "Run chat-plus");
        check("game command runs as the game's", route("p", null, true), "Run ");
        check("shared, first match runs it without a list", route("roll", null, true), "Run aaa-clash-test");
        check("shared, ask", route("clear", null, false), "Ask aaa-clash-test,chat-plus");
        check("pick", route("clear", 2, false), "Run chat-plus");
        check("pick out of range", route("clear", 3, true), "NoPick 2");
        check("pick of an unknown command", route("dance", 1, true), "NoPick 0");

        var grouped = CommandRouter.help(all, true);
        check("grouped help: headings in numbering order", [for (l in grouped) if (StringTools.startsWith(l, "## ")) l].join("|"),
            "## Clash Test|## Chat Plus|## Other Mod|## Game");
        check("grouped help: shared command marked under each owner", [for (l in grouped) if (l.indexOf("[/") >= 0) l].join("|"),
            "/roll <max> - test roll [/roll:1]|/clear - test clear [/clear:1]|/clear - remove chat messages (what is removed: Mod Settings) [/clear:2]|/roll - other roll [/roll:2]");
        var flat = CommandRouter.help(all, false);
        check("flat help: same lines without headings", flat.length, grouped.length - 4);
        check("flat help: other mods named", flat[2], "/clear - test clear (Clash Test) [/clear:1]");
        check("flat help: own and game lines unnamed", [flat[5], flat[flat.length - 1]].join("|"),
            "/leave - leave your group|Tab, Shift+Tab - switch channel while typing");
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
        check("order map, group, friends, book; one per account; self left out", [for (s in found) s.uid + ":" + s.source].join(","),
            "map:map,grp:group,new:friend,old:chat");
        check("no match", PlayerLookup.candidates("Nobody", onMap, group, friends, book, "me").length, 0);

        var now = new Date(2026, 10, 21, 22, 0, 0).getTime();
        var today = new Date(2026, 10, 21, 21, 14, 0).getTime();
        var earlier = new Date(2026, 10, 20, 18, 2, 0).getTime();
        check("live on map", PlayerLookup.describe({name: "S", uid: "1", seen: now, source: OnMap, className: "Rogue", level: 28, live: true}, now),
            "Rogue, level 28, on your map");
        check("live friend", PlayerLookup.describe({name: "S", uid: "1", seen: now, source: Friend, online: false, live: true}, now), "friend, offline");
        check("whisper today", PlayerLookup.describe({name: "S", uid: "1", seen: today, source: Chat, channel: "whisper"}, now), "whispered with you (21:14)");
        check("group yesterday", PlayerLookup.describe({name: "S", uid: "1", seen: earlier, source: InGroup, level: 12}, now),
            "level 12, was in your group (20.11. 18:02)");
    }

    static function noteFormat():Void {
        check("single line", NoteFormat.toMarkup("Group invite sent to <Anna>"), '<font color="#FF9933">[Chat Plus] Group invite sent to &lt;Anna&gt;</font>');
        check("help", NoteFormat.toMarkup("Chat commands:\n/w <name> - whisper\nno command - here"),
            '<font color="#FF9933">[Chat Plus] Chat commands:</font><br/>' +
            '<font color="#8CC8FF">/w &lt;name&gt;</font><font color="#FF9933"> - whisper</font><br/>' + '<font color="#FF9933">no command - here</font>');
        check("key line", NoteFormat.toMarkup("x\nTab - switch", false),
            '<font color="#FF9933">x</font><br/><font color="#8CC8FF">Tab</font><font color="#FF9933"> - switch</font>');
        check("error note", NoteFormat.toMarkup("Error while x: y\n/w - z", true, true),
            '<font color="#E8604C">[Chat Plus] Error while x: y</font><br/><font color="#E8604C">/w - z</font>');
        check("heading gold without its mark, command line unchanged", NoteFormat.toMarkup("x\n## Chat Plus\n/leave - y", false),
            '<font color="#FF9933">x</font><br/><font color="#FFD24A">Chat Plus</font><br/>' +
            '<font color="#8CC8FF">/leave</font><font color="#FF9933"> - y</font>');
        check("command without description", NoteFormat.toMarkup("x\n/leave"),
            '<font color="#FF9933">[Chat Plus] x</font><br/><font color="#FF9933">/leave</font>');
    }

    static function gameCheck():Void {
        check("nothing missing", GameCheck.report(GameCheck.missing(_ -> true)), null);
        var gone = GameCheck.missing(r -> r.member != "handleCommand" && r.type != "st.Channel");
        check("missing ones found", [for (r in gone) GameCheck.name(r)].join(","), "ui.hud.ChatBox.handleCommand,st.Channel");
        check("report", GameCheck.report(gone),
            "Game elements not found (game update?), these features may not work:\nui.hud.ChatBox.handleCommand - chat commands\nst.Channel - mod messages, /w");
        check("static name", GameCheck.name({type: "HText", member: "withColor", kind: StaticMethod, feature: ""}), "HText::withColor");
        check("every requirement but types names a member",
            [for (r in GameCheck.REQUIRED) if ((r.member == null) != (r.kind == Type)) GameCheck.name(r)].length, 0);
    }

    static function texts():Void {
        var placeholders = ~/\{\d\}/g;
        function marks(s:String):String {
            var found = [];
            placeholders.map(s, r -> {
                found.push(r.matched(0));
                "";
            });
            found.sort(Reflect.compare);

            return found.join("");
        }

        check("every English text has a German one", [for (k in Texts.EN.keys()) if (!Texts.DE.exists(k)) k].join(","), "");
        check("no German text without an English one", [for (k in Texts.DE.keys()) if (!Texts.EN.exists(k)) k].join(","), "");
        check("same placeholders in both languages",
            [for (k in Texts.EN.keys()) if (Texts.DE.exists(k) && marks(Texts.EN.get(k)) != marks(Texts.DE.get(k))) k].join(","), "");
        check("every section has a heading in both languages",
            [for (s in Settings.SECTIONS) if (!Texts.EN.exists("title." + s.id) || !Texts.DE.exists("title." + s.id)) s.id].join(","), "");
        check("every setting has a label and a tooltip", [for (t in Settings.TOGGLES)
            if (!Texts.EN.exists("set." + t.key + ".label") || !Texts.EN.exists("set." + t.key + ".tip")) t.key].join(","), "");
        check("English by default", Texts.get("invite.sent", ["Anna"]), "Group invite sent to Anna");
        check("check result names the version", Texts.get("check.ok", [45, chatplus.Version.VERSION]),
            "Chat Plus " + chatplus.Version.VERSION + ": all 45 game elements the mod uses were found.");
        check("unknown key shows the key", Texts.get("no.such.key"), "no.such.key");
        Texts.lang = "de";
        check("German", Texts.get("invite.sent", ["Anna"]), "Gruppeneinladung an Anna gesendet");
        check("German, repeated placeholder", Texts.get("ignore.done", ["Bob"]), "Bob wird ignoriert. /unignore Bob macht das rückgängig");
        check("German help keeps the command format", CommandRouter.help(ModCommands.all([]), true)[2],
            "/w, /whisper, /tell <Name> [Text] - einem Spieler zuflüstern");
        check("German text of a registered command", ModCommands.fromEntry(clashEntry(null)).commands[0].line, "/roll <max> - Testwurf");
        check("German description", PlayerLookup.describe({name: "S", uid: "1", seen: 0, source: OnMap, level: 28, live: true}, 0),
            "Stufe 28, auf deiner Karte");
        var formats:Dynamic = haxe.Json.parse(Settings.formatsJson());
        var configs:Array<Dynamic> = formats.configs;
        check("German settings page", configs[1].label, "Uhrzeit");
        check("German headings", [for (c in configs) if (c.type == "title") c.label].join(","),
            "Chat,Charakterwechsel,Spieler & Befehle,/clear,Chatgröße,Fehlersuche");
        Texts.lang = "fr";
        check("other languages get English", Texts.get("clear.done"), "Chat cleared");
        Texts.lang = "en";
    }

    static function check(name:String, actual:Dynamic, expected:Dynamic):Void {
        if (actual == expected) {
            return;
        }

        failures++;
        Sys.println('FAIL $name: expected $expected, got $actual');
    }
}
