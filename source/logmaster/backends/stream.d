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

abstract class StreamBackend : LoggingBackend {
    string[] cache;

    this(string longTitle, string shortTitle) {
        super(longTitle, shortTitle);
        this.indexingPercentage = 1.0;
    }

    override LogLine opIndex(long i) { return LogLine(i, cache[i]); }
    override ulong opDollar() { return cache.length; }
    override ulong start() { return 0; }
    override ulong end() { return cache.length-1; }
}
