package chatplus;

/// How a game element is looked up.
enum CheckKind {
    Method;
    StaticMethod;
    Type;
}

/// A game type or function the mod hooks or calls, and the feature that stops working without it.
typedef Requirement = {type:String, ?member:String, kind:CheckKind, feature:String};

/// The game elements the mod depends on, checked at start so a game update that renames one shows up in the chat.
class GameCheck {
    public static final REQUIRED:Array<Requirement> = [
        // Hooks
        {type: "st.player.ChatClient", member: "resetHistory", kind: StaticMethod, feature: "keep chat on character switch"},
        {type: "ui.hud.ChatBox", member: "resetChannels", kind: StaticMethod, feature: "keep chat on character switch"},
        {type: "ui.hud.ChatBox", member: "handleCommand", kind: Method, feature: "chat commands"},
        {type: "ui.hud.ChatBox", member: "init", kind: Method, feature: "keep a closed chat closed, address book"},
        {type: "st.player.ChatClient", member: "localReceiveMessage", kind: Method, feature: "address book, mod messages"},
        {type: "ui.hud.ChatBoxMessage", member: "init", kind: Method, feature: "timestamps, mod messages"},
        // Calls
        {type: "st.Channel", kind: Type, feature: "mod messages, /w"},
        {type: "hl.types.ArrayObj", member: "getDyn", kind: Method, feature: "all"},
        {type: "hl.types.ArrayObj", member: "splice", kind: Method, feature: "keep chat on character switch"},
        {type: "HText", member: "withColor", kind: StaticMethod, feature: "timestamps"},
        {type: "HText", member: "reason", kind: StaticMethod, feature: "/invite"},
        {type: "HText", member: "unitById", kind: StaticMethod, feature: "address book"},
        {type: "ui.hud.ChatBoxMessage", member: "getChannelColor", kind: StaticMethod, feature: "timestamps"},
        {type: "ui.comp.FmtText", member: "set_text", kind: Method, feature: "timestamps, mod messages"},
        {type: "ui.BaseElement", member: "get_myPlayer", kind: Method, feature: "chat commands"},
        {type: "ui.hud.ChatBox", member: "chatError", kind: Method, feature: "chat commands"},
        {type: "ui.hud.ChatBox", member: "setChannel", kind: Method, feature: "/w"},
        {type: "st.Group", member: "hasInvitePlayerAllowed", kind: Method, feature: "/invite"},
        {type: "st.Group", member: "get_isSolo", kind: Method, feature: "/leave"},
        {type: "st.Player", member: "leaveGroup", kind: Method, feature: "/leave"},
        {type: "st.Player", member: "getName", kind: Method, feature: "address book"},
        {type: "st.player.Whispers", member: "sendInviteGroup", kind: Method, feature: "/invite"},
        {type: "domkit.Properties", member: "hasClass", kind: Method, feature: "keep a closed chat closed"},
        {type: "domkit.Properties", member: "toggleClass", kind: Method, feature: "keep a closed chat closed"},
        {type: "GameApp", member: "get", kind: StaticMethod, feature: "address book"},
    ];

    /// The requirements `exists` does not find.
    public static function missing(exists:Requirement->Bool):Array<Requirement> {
        return [for (r in REQUIRED) if (!exists(r)) r];
    }

    /// One chat note for the missing elements, or null when nothing is missing.
    public static function report(missing:Array<Requirement>):Null<String> {
        if (missing.length == 0) return null;
        var lines = ["Game elements not found (game update?), these features may not work:"];
        for (r in missing) lines.push(name(r) + " - " + r.feature);
        return lines.join("\n");
    }

    public static function name(r:Requirement):String {
        return r.member == null ? r.type : r.type + (r.kind == StaticMethod ? "::" : ".") + r.member;
    }
}
