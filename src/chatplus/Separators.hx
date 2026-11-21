package chatplus;

/// Decides where a "character switch" separator goes while a chat window shows the message history
/// in order. A separator goes before the first message received after a switch, and only when
/// an earlier message is shown above it.
class Separators {
    var switches:Array<Float> = [];
    var lastStamp:Null<Float> = null;

    public function new() {}

    /// Records a character switch at process time `time`.
    public function addSwitch(time:Float):Void {
        switches.push(time);
    }

    /// A new chat window starts showing the history from the beginning.
    public function startWindow():Void {
        lastStamp = null;
    }

    /// True when the message with `stamp` is the first one after a switch. Call once per shown message, in order.
    public function before(stamp:Float):Bool {
        var previous = lastStamp;
        lastStamp = stamp;
        if (previous == null) return false;
        for (time in switches) if (previous < time && stamp >= time) return true;
        return false;
    }
}
