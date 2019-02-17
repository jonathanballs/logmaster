module logmaster.filters;

import std.algorithm.searching : canFind;
import std.concurrency;
import std.regex;
import std.stdio;
import std.variant;
import std.typecons;

import logmaster.backends;
import logmaster.backendevents;
import logmaster.loglines;
alias FilterID = Typedef!(int);
private static FilterID availableID = 0;

struct FilterEvent {
    FilterID filterID;
    Variant payload;
}

class RegexFilterLogLines : LogLines {
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
class RegexFilter {
    LoggingBackend backend;
    string filterText;
    FilterID id;

    RegexFilterLogLines _lines;
    LogLines lines() { return _lines; }

    this(LoggingBackend backend, string filterText) {
        this.id = availableID++;
        this.backend = backend;
        this.filterText = filterText;
        this._lines = new RegexFilterLogLines(backend);
    }

    Tid tid;
    void spawnIndexingThread() {
        this.tid = spawn((shared LoggingBackend _backend, FilterID id, string filterString) {


            void sendNewLine(long lineID) {
                auto event = new FilterEvent(id);
                event.payload = lineID;
                BackendEvent b;
                b.backendID = cast(BackendID) _backend.id;
                b.payload = *event;
                send(ownerTid(), b);
            }

            auto re = regex(filterString);
            auto backend = cast(LoggingBackend) _backend;
            foreach(LogLine line; backend.lines) {
                if (line.message.matchFirst(re)) {
                    writeln(line);
                    sendNewLine(line.lineID);
                }
            }
            writeln();
        }, cast(shared) backend, this.id, filterText);
    }

    bool handleEvent(FilterEvent event) {
        assert(event.filterID == this.id);
        this._lines.matchingLines ~= event.payload.get!long;
        if (lines[$-1].message.length > lines.longestLineLength) {
            _lines._longestLineLength = lines[$-1].message.length;
        }
        return true;
    }

    ~this() {
        writeln("Destructing filter");
    }
}
