module logmaster.filters.regex;

import std.algorithm.searching : canFind;
import std.concurrency;
import std.regex;
import std.stdio;
import std.variant;

import logmaster.backends;

/**
 * Just a quick experiment. A backend which is actually just a filter for another
 * log backend.
 */

class BackendRegexLogLines : LogLines {
    LoggingBackend backend;
    long[] matchingLines;

    this(LoggingBackend backend) {
        this.backend = backend;
    }

    override LogLine opIndex(long i) { return backend.lines[matchingLines[i]]; }
    override ulong length() { return matchingLines.length; }
    override ulong opDollar() { return this.length; }
    override int opApply(int delegate(LogLine) dlg) {
        foreach (l; this.matchingLines) {
            int result = dlg(this[l]);
            if (result) return result;
        }
        return 0;
    }
    ulong _longestLineLength;
    override ulong longestLineLength() { return _longestLineLength; }
}

// A backend but instead of 
class BackendRegexFilter {
    LoggingBackend backend;
    string filterText;

    BackendRegexLogLines _lines;
    LogLines lines() { return _lines; }

    this(LoggingBackend backend, string filterText) {
        this.backend = backend;
        this.filterText = filterText;
        this._lines = new BackendRegexLogLines(backend);
    }

    Tid tid;
    void spawnIndexingThread() {
        this.tid = spawn((shared LoggingBackend _backend, string filterString) {
            auto re = regex(filterString);
            auto backend = cast(LoggingBackend) _backend;
            foreach(LogLine line; backend.lines) {
                if (line.message.matchFirst(re)) {
                    writeln("matched");
                    // backend._lines.matchingLines ~= line.lineID;
                }
            }
        }, cast(shared) backend, filterText);
    }
}
