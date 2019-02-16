module logmaster.loglines;

import std.typecons;

alias LogLine = Tuple!(ulong, "lineID", string, "message");

class LogLines {
    LogLine opIndex(long i) { return LogLine(0, "Test"); }
    ulong opDollar() { return this.length; }
    ulong length() { return 0; }
    int opApply(int delegate(LogLine) dlg) { return 0; }
    ulong longestLineLength() { return 0; }
}
