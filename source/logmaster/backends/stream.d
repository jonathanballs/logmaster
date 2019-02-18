module logmaster.backends.stream;

import std.concurrency;
import std.file;
import std.stdio;
import std.string;
import std.variant;
import core.thread;
import core.time;

import logmaster.backends;
import logmaster.backendevents;

struct EventNewLine {
    string newLine;
}

private class StreamLogLines : LogLines {
    string[] cache;
    override LogLine opIndex(long i) { return LogLine(i, cache[i]); }
    override ulong length() { return cache.length; }
    override int opApply(int delegate(LogLine) dlg) const {
        foreach (i, line; cache) {
            int result = dlg(LogLine(i, line));
            if (result) return result;
        }
        return 0;
    }
    ulong _longestLineLength;
    override ulong longestLineLength() { return _longestLineLength; }
}

abstract class StreamBackend : LoggingBackend {
    private StreamLogLines _lines;

    this(string longTitle, string shortTitle) {
        super(longTitle, shortTitle);
        this.indexingPercentage = 1.0;
        this._lines = new StreamLogLines();
    }

    override LogLines lines() {
        return _lines;
    }

    override void handleEvent(Variant v) {
        if (v.type == typeid(EventNewLine)) {
            auto e = v.get!EventNewLine;
            this._lines.cache ~= e.newLine;
            import std.algorithm : max;
            this._lines._longestLineLength = max(_lines._longestLineLength, e.newLine.length);
            this.onNewLines.emit();
        } else {
            super.handleEvent(v);
        }
    }
}
