module logmaster.backends.filters.regex;

import std.algorithm.searching : canFind;
import std.variant;
import std.regex;

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
    long[] matchingLineNumbers;

    this(LoggingBackend backend, string filterText) {
        this.backend = backend;
        this.filterText = filterText;
        this._lines = new BackendRegexLogLines(backend);

        // For now lets just do it here
        auto re = regex(filterText);
        foreach(LogLine line; this.backend.lines) {
            if (line.message.matchFirst(re)) {
                if (line.message.length > _lines._longestLineLength) { 
                    _lines._longestLineLength = line.message.length;
                }
                this._lines.matchingLines ~= line.lineID;
            }
        }
    }
}
