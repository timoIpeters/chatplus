package chatplus;

import chatplus.Game as G;

/// A row of channel buttons (All, Group, Local, last whisper partner; names are at most 12 characters) above the chat's input line. A click selects
/// the channel and focuses the input; the button of the selected channel is fully opaque.
class ChannelBar {
    // st.Channel constructor indexes, in button order.
    static final CHANNELS = [1, 4, 0];
    static inline var CHANNEL_WHISPER = 3;
    static inline var INACTIVE_ALPHA = 0.55;

    final chat:Dynamic;
    final row:Dynamic;
    final footer:Dynamic;
    // Button per channel index, and the whisper button with the channel it was labelled for.
    final buttons:Map<Int, Dynamic> = [];
    var whisperButton:Dynamic;
    var whisperChannel:Dynamic;

    public function new(chat:Dynamic) {
        this.chat = chat;
        footer = G.field(chat, "footer");
        if (footer == null) throw "The chat has no footer";
        var node = G.staticCall("domkit.Properties", "createNew", ["flow", G.field(chat, "dom"), [], {id: "chatPlusChannels"}]);
        row = G.field(node, "obj");
        if (row == null) throw "Could not create the channel row";
        style(row, ["spacing" => 4, "padding-left" => 5, "padding-top" => 3, "padding-bottom" => 3]);
        // Directly above the footer (dropdown and input), which is the last child of the vertical chat layout.
        var index:Int = G.call("h2d.Object", "getChildIndex", chat, [footer]);
        G.call("h2d.Flow", "addChildAt", chat, [row, index]);
        for (kind in CHANNELS) {
            var option = optionOf(kind);
            if (option != null) buttons.set(kind, button(G.field(option, "name"), G.field(option, "value")));
        }
    }

    /// Call once per frame while the chat exists.
    public function update():Void {
        G.call("h2d.Object", "set_visible", row, [G.field(footer, "visible") == true]);
        var lastWhisp = G.staticField("ui.hud.ChatBox", "lastWhisp");
        if (lastWhisp != whisperChannel) {
            whisperChannel = lastWhisp;
            if (whisperButton != null) G.call("h2d.Object", "remove", whisperButton);
            whisperButton = lastWhisp == null ? null : button("@" + Type.enumParameters(lastWhisp)[1], lastWhisp);
        }
        var selected = G.call("ui.comp.Dropdown", "get_selectedValue", G.field(chat, "channelDropdown"));
        var selectedKind = selected == null ? -1 : Type.enumIndex(selected);
        for (kind => b in buttons) setActive(b, kind == selectedKind);
        if (whisperButton != null) {
            var selectedUid:String = selectedKind == CHANNEL_WHISPER ? Type.enumParameters(selected)[0] : null;
            var whisperUid:String = Type.enumParameters(whisperChannel)[0];
            var same = selectedUid != null && selectedUid == whisperUid;
            setActive(whisperButton, same);
        }
    }

    public function isFor(chat:Dynamic):Bool {
        return this.chat == chat;
    }

    function optionOf(kind:Int):Dynamic {
        for (option in G.elements(G.staticField("ui.hud.ChatBox", "channelOptions")))
            if (Type.enumIndex(G.field(option, "value")) == kind) return option;
        return null;
    }

    function button(label:String, channel:Dynamic):Dynamic {
        var node = G.staticCall("domkit.Properties", "createNew", ["button", G.field(row, "dom"), [label], {"class": "chat-plus-channel"}]);
        var b = G.field(node, "obj");
        if (b == null) throw "Could not create a channel button";
        // The game's default button is at least 50 px high with wide padding.
        style(b, ["min-height" => 0, "min-width" => 0, "height" => 26, "padding-left" => 8, "padding-right" => 8, "padding-top" => 2, "padding-bottom" => 2]);
        G.call("ui.UIElement", "set_onClick", b, [() -> select(channel)]);
        return b;
    }

    function select(channel:Dynamic):Void {
        try {
            G.call("ui.hud.ChatBox", "setChannel", chat, [channel]);
            G.call("ui.hud.ChatBox", "focus", chat);
        } catch (error:Dynamic) trace("[ChatPlus] error while selecting a channel: " + Std.string(error));
    }

    static function setActive(b:Dynamic, active:Bool):Void {
        var alpha = active ? 1.0 : INACTIVE_ALPHA;
        if (G.field(b, "alpha") != alpha) HlxRuntime.setField(b, "alpha", alpha);
    }

    static function style(element:Dynamic, values:Map<String, Dynamic>):Void {
        var dom = G.field(element, "dom");
        for (key => value in values) G.call("domkit.Properties", "initStyle", dom, [key, value]);
    }
}
