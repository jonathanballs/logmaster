module logmaster.backend;

import std.concurrency;

/// An event that is passed from a backend to the frontend
class Bevent {
    Tid tid;
    this() {
        tid = thisTid();
    }
}

class BeventNewLogLines : Bevent {
    string line;
    this(string _line) {
        super();
        this.line = _line;
    }
}

abstract class LoggingBackend {
    Tid tid;

    string title;
    abstract void readLines();

    this(string _title) {
        this.title = _title;
    }

    void start() {
        this.tid = spawn((shared LoggingBackend self) {
            (cast(LoggingBackend) self).readLines();
        }, cast(shared) this);
    }

    void newLogLineCallback(string line) {
        const BeventNewLogLines event = new BeventNewLogLines(line);
        ownerTid.send(cast(shared) event);
    }
}
