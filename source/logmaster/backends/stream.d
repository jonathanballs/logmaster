module logmaster.backends.stream;

import std.concurrency;
import std.file;
import std.stdio;
import std.string;
import std.variant;
import core.thread;
import core.time;

import logmaster.backend;
import logmaster.backendevents;

struct EventNewLine {
    string newLine;
}

private class StreamLogLines : LogLines {
    string[] cache;
    override LogLine opIndex(long i) { return LogLine(i, cache[i]); }
    override ulong length() { return cache.length; }
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
            this.onNewLines.emit();
        }
    }

    override ulong start() { return 0; }
    override ulong end() { return lines.length-1; }
}
