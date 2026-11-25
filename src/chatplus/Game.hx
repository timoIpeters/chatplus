package chatplus;

import hlx.runtime.ResolvedMember;

/// Reflection helpers for game objects. Game objects stay in the game's HL module and are only
/// read and called through these functions.
class Game {
    static var members:Map<String, ResolvedMember> = [];

    /// Value of a field, or null when the object is null or has no such field.
    public static function field(object:Dynamic, name:String):Dynamic {
        if (object == null) {
            return null;
        }

        try {
            return HlxRuntime.resolveField(object, name);
        } catch (_:Dynamic) {
            return null;
        }
    }

    public static function integer(value:Dynamic, fallback:Int = 0):Int {
        if (value == null) {
            return fallback;
        }

        var n = Std.parseFloat(Std.string(value));

        return Math.isFinite(n) ? Std.int(n) : fallback;
    }

    static function memberOrNull(type:String, name:String, isStatic:Bool):Null<ResolvedMember> {
        var key = type + (isStatic ? "::" : ".") + name;
        if (members.exists(key)) {
            return members[key];
        }

        var t = HlxRuntime.resolveType(type);
        if (t == null) {
            return null;
        }

        var m = isStatic ? HlxRuntime.resolveStaticMember(t, name) : HlxRuntime.resolveMember(t, name);
        if (m != null) {
            members[key] = m;
        }

        return m;
    }

    /// Calls the method `name` declared on game type `type`.
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        var m = memberOrNull(type, name, false);
        if (m == null) {
            throw "Game member unavailable: " + type + "." + name;
        }

        var all:Array<Dynamic> = [object];

        if (args != null) {
            for (a in args) {
                all.push(a);
            }
        }

        return HlxRuntime.callResolved(m, all);
    }

    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        var m = memberOrNull(type, name, true);
        if (m == null) {
            throw "Game member unavailable: " + type + "::" + name;
        }

        return HlxRuntime.callResolved(m, args);
    }

    public static function staticField(type:String, name:String):Dynamic {
        var t = HlxRuntime.resolveType(type);
        return t == null ? null : HlxRuntime.resolveStaticField(t, name);
    }

    /// Elements of a game array (`hl.types.ArrayObj`, `ArrayDyn`) or of a replicated list that holds one in `array`.
    public static function elements(array:Dynamic):Array<Dynamic> {
        if (array == null) {
            return [];
        }

        var type = hl.Type.getDynamic(array).getTypeName();
        if (type != "hl.types.ArrayObj" && type != "hl.types.ArrayDyn") {
            return elements(field(array, "array"));
        }

        var count = integer(field(array, "length"));

        return [for (i in 0...count) call(type, "getDyn", array, [i])];
    }

    /// Whether the game has the type or function `r` names.
    public static function exists(r:GameCheck.Requirement):Bool {
        var t = HlxRuntime.resolveType(r.type);
        if (t == null) {
            return false;
        }

        return switch (r.kind) {
            case Type: true;
            case Method: HlxRuntime.resolveMember(t, r.member) != null;
            case StaticMethod: HlxRuntime.resolveStaticMember(t, r.member) != null;
        }
    }
}
