package chatplus;

/// The chat size while a resize handle is dragged.
class ChatSize {
    /// Start size plus the drag distance (`dy` positive = upwards), at least the game's size and at most `maxWidth`×`maxHeight`.
    public static function dragged(startWidth:Int, startHeight:Int, dx:Float, dy:Float, maxWidth:Int, maxHeight:Int):{width:Int, height:Int} {
        return {
            width: clamp(Math.round(startWidth + dx), Settings.CHAT_WIDTH_MIN, maxWidth),
            height: clamp(Math.round(startHeight + dy), Settings.CHAT_HEIGHT_MIN, maxHeight),
        };
    }

    // The minimum wins over a smaller maximum (a screen smaller than the game's chat).
    static function clamp(value:Int, min:Int, max:Int):Int {
        return value > max ? (max < min ? min : max) : (value < min ? min : value);
    }
}
