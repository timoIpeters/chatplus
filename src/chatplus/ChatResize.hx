package chatplus;

import chatplus.Game as G;

/// Lets the chat be dragged larger: handles along the inside of its top edge (height), right edge (width)
/// and top-right corner (both), shown as a red line with the game's drag cursor while hovered. The chat keeps
/// its bottom-left corner. The size is applied every frame and after each style pass, because the game's chat
/// style (480×250) is re-applied whenever the chat or one of its lines changes state.
class ChatResize {
    /// The handles of the current chat window.
    public static var current:Null<ChatResize>;

    // Only the part of a handle inside the chat receives the mouse. Thin, to leave the close button
    // and most of the message scrollbar free.
    static inline var HANDLE = 4;
    static inline var CORNER = 8;
    static inline var LINE_COLOR = 0xD75C4E;
    static inline var LINE_ALPHA = 0.8;
    // The game's text input is capped at 370 px in a 480 px chat; it keeps that margin for the dropdown.
    static inline var INPUT_MARGIN = Settings.CHAT_WIDTH_MIN - 370;

    final chat:Dynamic;
    final footer:Dynamic;
    final hoverCursor:Dynamic;
    final dragCursor:Dynamic;
    final top:Dynamic;
    final right:Dynamic;
    final corner:Dynamic;
    // Set while a handle is dragged: the handle, what it changes and where the drag started.
    var dragged:Dynamic = null;
    var dragWidth = false;
    var dragHeight = false;
    var startX = 0.0;
    var startY = 0.0;
    var startWidth = 0;
    var startHeight = 0;

    public function new(chat:Dynamic) {
        this.chat = chat;
        footer = G.field(chat, "footer");
        if (footer == null) throw "The chat has no footer";
        var ui = G.staticField("ui.BaseUI", "current");
        hoverCursor = G.call("ui.BaseUI", "getIconCursor", ui, ["CursorButtonDraggable"]);
        dragCursor = G.call("ui.BaseUI", "getIconCursor", ui, ["CursorButtonDragging"]);
        top = handle(false, true);
        right = handle(true, false);
        corner = handle(true, true);
        G.call("ui.UIElement", "bindUpdate", chat, [(dt:Float) -> update()]);
        current = this;
    }

    function handle(width:Bool, height:Bool):Dynamic {
        var node = G.staticCall("domkit.Properties", "createNew", ["flow", G.field(chat, "dom"), [], {"class": "chat-plus-resize"}]);
        var flow = G.field(node, "obj");
        if (flow == null) throw "Could not create a resize handle";
        var properties = G.call("h2d.Flow", "getProperties", chat, [flow]);
        G.call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
        G.call("h2d.Flow", "set_enableInteractive", flow, [true]);
        var interactive = G.field(flow, "interactive");
        if (interactive == null) throw "The resize handle has no interactive";
        if (hoverCursor != null) G.call("h2d.Interactive", "set_cursor", interactive, [hoverCursor]);
        // A red line, visible while the handle is hovered or dragged.
        G.call("h2d.Flow", "set_backgroundTile", flow, [G.staticCall("h2d.Tile", "fromColor", [LINE_COLOR, 1, 1, 1.0])]);
        showLine(flow, false);
        // During a drag only the dragged handle shows its line, also when the mouse passes over the others.
        HlxRuntime.setField(interactive, "onOver", (e:Dynamic) -> if (dragged == null) showLine(flow, true));
        HlxRuntime.setField(interactive, "onOut", (e:Dynamic) -> if (dragged != flow) showLine(flow, false));
        HlxRuntime.setField(interactive, "onPush", (e:Dynamic) -> startDrag(flow, interactive, width, height));
        return flow;
    }

    function startDrag(flow:Dynamic, interactive:Dynamic, width:Bool, height:Bool):Void {
        try {
            var p = pointer();
            startX = p.x;
            startY = p.y;
            startWidth = ChatPlus.settings.chatWidth;
            startHeight = ChatPlus.settings.chatHeight;
            dragged = flow;
            dragWidth = width;
            dragHeight = height;
            if (dragCursor != null) G.call("h2d.Interactive", "set_cursor", interactive, [dragCursor]);
            G.call("h2d.Interactive", "startCapture", interactive, [(e:Dynamic) -> onDragEvent(flow, interactive, e), null, null]);
        } catch (error:Dynamic) ChatPlus.log("starting to resize the chat", error);
    }

    function onDragEvent(flow:Dynamic, interactive:Dynamic, e:Dynamic):Void {
        try {
            var kind = Type.enumConstructor(G.field(e, "kind"));
            if (kind == "EMove") {
                var p = pointer();
                var size = ChatSize.dragged(startWidth, startHeight, dragWidth ? p.x - startX : 0, dragHeight ? startY - p.y : 0, maxWidth(), maxHeight());
                ChatPlus.settings.chatWidth = size.width;
                ChatPlus.settings.chatHeight = size.height;
                applySize();
            } else if (kind == "ERelease" || kind == "EReleaseOutside") {
                G.call("h2d.Interactive", "stopCapture", interactive);
                dragged = null;
                dragWidth = dragHeight = false;
                if (hoverCursor != null) G.call("h2d.Interactive", "set_cursor", interactive, [hoverCursor]);
                for (h in [top, right, corner]) showLine(h, false);
                ChatPlus.saveSettings();
                if (ChatPlus.settings.chatWidth != startWidth) rebuildLines();
            }
        } catch (error:Dynamic) ChatPlus.log("resizing the chat", error);
    }

    /// Lines keep the width they were laid out for. They are removed and the game builds them again from the
    /// history at the new width, as in a new scene: its per-frame poll starts over when `messageIndex` is 0.
    public function rebuildLines():Void {
        rebuild(chat);
    }

    /// Removes the shown lines of `chat` (a `ui.hud.ChatBox`); the game builds them again from the history.
    public static function rebuild(chat:Dynamic):Void {
        if (G.field(chat, "parent") == null) return;
        var messages = G.field(chat, "messages");
        var count:Int = G.call("h2d.Object", "get_numChildren", messages);
        var lines = [];
        for (i in 0...count) {
            var child = G.call("h2d.Object", "getChildAt", messages, [i]);
            // The scrollbar and other parts of the message list stay.
            if (child != null && hl.Type.getDynamic(child).getTypeName() == "ui.hud.ChatBoxMessage") lines.push(child);
        }
        for (line in lines) G.call("h2d.Object", "remove", line);
        HlxRuntime.setField(chat, "messageIndex", 0);
    }

    // A handle gets no "mouse out" when a menu or window opens over the game, so its line would stay.
    // While a line shows, the mouse has to be over that handle.
    function hideStaleLines():Void {
        var shown = [for (h in [top, right, corner]) if (h != dragged && number(G.field(h, "alpha")) > 0) h];
        if (shown.length == 0) return;
        var p = pointer();
        var x = p.x - number(G.field(chat, "x"));
        var y = p.y - number(G.field(chat, "y"));
        for (h in shown) {
            var left = number(G.field(h, "x"));
            var upper = number(G.field(h, "y"));
            var inside = x >= left && x < left + number(G.field(h, "calculatedWidth")) && y >= upper && y < upper + number(G.field(h, "calculatedHeight"));
            if (!inside) showLine(h, false);
        }
    }

    static function showLine(flow:Dynamic, visible:Bool):Void {
        HlxRuntime.setField(flow, "alpha", visible ? LINE_ALPHA : 0.0);
    }

    // The mouse in the coordinates of the chat's parent, where the chat's position and size are measured.
    function pointer():{x:Float, y:Float} {
        var scene = G.call("h2d.Object", "getScene", chat);
        var p = G.call("h2d.Object", "localToGlobal", chat, [null]);
        HlxRuntime.setField(p, "x", G.call("h2d.Scene", "get_mouseX", scene));
        HlxRuntime.setField(p, "y", G.call("h2d.Scene", "get_mouseY", scene));
        G.call("h2d.Object", "globalToLocal", G.field(chat, "parent"), [p]);
        return {x: number(G.field(p, "x")), y: number(G.field(p, "y"))};
    }

    // Up to the right edge of the chat's parent, and up to its top edge (the chat grows upwards).
    function maxWidth():Int {
        var parent = G.field(chat, "parent");
        var available = number(G.field(parent, "calculatedWidth"));
        if (available <= 0) available = number(G.field(G.call("h2d.Object", "getScene", chat), "width"));
        return Std.int(available - number(G.field(chat, "x")));
    }

    function maxHeight():Int {
        return Std.int(number(G.field(chat, "y")) + number(G.field(chat, "calculatedHeight")));
    }

    function update():Void {
        try {
            var visible = G.field(footer, "visible") == true;
            for (h in [top, right, corner]) if (G.field(h, "visible") != visible) G.call("h2d.Object", "set_visible", h, [visible]);
            if (!visible) return;
            applySize();
            var width = ChatPlus.settings.chatWidth;
            var height = ChatPlus.settings.chatHeight;
            place(top, 0, 0, width - CORNER, HANDLE);
            place(right, width - HANDLE, CORNER, HANDLE, height - CORNER);
            place(corner, width - CORNER, 0, CORNER, CORNER);
            hideStaleLines();
        } catch (error:Dynamic) ChatPlus.log("applying the chat size", error);
    }

    /// Gives the chat the saved size unless it is minimized (the game's style then sets it to 0×0 and hides its content).
    public function applySize():Void {
        if (G.field(footer, "visible") != true || G.field(chat, "parent") == null) return;
        var width = ChatPlus.settings.chatWidth;
        var height = ChatPlus.settings.chatHeight;
        for (name in ["minWidth", "maxWidth"]) setInt(chat, name, width);
        for (name in ["minHeight", "maxHeight"]) setInt(chat, name, height);
        var input = G.field(G.field(chat, "messageInput"), "input");
        if (input != null && number(G.field(input, "maxWidth")) != width - INPUT_MARGIN) G.call("h2d.Text", "set_maxWidth", input, [width - INPUT_MARGIN]);
    }

    static function place(flow:Dynamic, x:Float, y:Float, width:Int, height:Int):Void {
        for (name in ["minWidth", "maxWidth"]) setInt(flow, name, width);
        for (name in ["minHeight", "maxHeight"]) setInt(flow, name, height);
        if (number(G.field(flow, "x")) != x || number(G.field(flow, "y")) != y) G.call("h2d.Object", "setPosition", flow, [x, y]);
    }

    static function setInt(flow:Dynamic, name:String, value:Int):Void {
        if (G.field(flow, name) != value) G.call("h2d.Flow", "set_" + name, flow, [value]);
    }

    static function number(value:Dynamic):Float {
        if (value == null) return 0;
        var n = Std.parseFloat(Std.string(value));
        return Math.isFinite(n) ? n : 0;
    }
}
