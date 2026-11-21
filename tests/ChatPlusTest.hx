import chatplus.ChatTime;
import chatplus.Settings;

class ChatPlusTest {
    static var failures = 0;

    static function main():Void {
        chatTime();
        settings();
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

    static function check(name:String, actual:Dynamic, expected:Dynamic):Void {
        if (actual == expected) return;
        failures++;
        Sys.println('FAIL $name: expected $expected, got $actual');
    }
}
