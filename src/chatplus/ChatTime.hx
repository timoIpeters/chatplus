package chatplus;

/// Turns a message's `localStamp` (seconds of the process clock `Sys.time()` when the client received it)
/// into wall-clock time, the same way the game does for system messages.
class ChatTime {
    /// `HH:MM` of `stamp`, given the process clock `sysNow` and the wall clock `dateNow` (ms) at the same moment.
    public static function format(stamp:Float, sysNow:Float, dateNow:Float):String {
        return DateTools.format(Date.fromTime(dateNow - (sysNow - stamp) * 1000), "%H:%M");
    }
}
