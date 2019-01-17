module logmaster.backend;

import std.concurrency;

alias BackendID = uint;
private static newId = 0;

/// An event that is passed from a backend to the frontend

struct BeventNewLogLines {
    Tid tid;
    BackendID backendId;
    string line;
    this(BackendID _backendId, string _line) {
        tid = thisTid();
        this.backendId = _backendId;
        this.line = _line;
    }
}

/// Tell thread to exit
shared struct BeventExitThread {
}

abstract class LoggingBackend {
    BackendID id;
    Tid tid;

    string shortTitle;
    string longTitle;
    abstract void readLines();

    /**
     * Create a new logging backend.
     * Params:
     *     _shortTitle = A shorter title for the sidebar.
     *     _longTitle  = A longer title for the titlebar.
     */
    this(string _shortTitle, string _longTitle) {
        this.id = newId++;
        this.shortTitle = _shortTitle;
        this.longTitle = _longTitle;
    }

    void start() {
        this.tid = spawn((shared LoggingBackend self) {
            (cast(LoggingBackend) self).readLines();
        }, cast(shared) this);
    }

    void newLogLineCallback(string line) {
        ownerTid.send(cast(shared) BeventNewLogLines(this.id, line));
    }
}
