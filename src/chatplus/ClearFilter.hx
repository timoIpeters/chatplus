package chatplus;

/// Which messages `/clear` removes, by the `st.Channel` constructor index of the message.
class ClearFilter {
    static inline var LOCAL = 0;
    static inline var ALL = 1;
    static inline var SYSTEM = 2;
    static inline var WHISPER = 3;
    static inline var GROUP = 4;
    static inline var SYSTEM_EVENT = 5;

    public static function removes(channel:Int, s:Settings):Bool {
        return switch (channel) {
            case LOCAL: s.clearLocal;
            case ALL: s.clearAll;
            case WHISPER: s.clearWhispers;
            case GROUP: s.clearGroup;
            case SYSTEM, SYSTEM_EVENT: s.clearSystem;
            default: s.clearSystem;
        }
    }
}
