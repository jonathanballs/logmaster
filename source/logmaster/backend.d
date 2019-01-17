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

/// Tell backend thread to exit
shared struct BeventExitThread {
}

/// Backend threw an exception
struct BeventException {
    Tid tid;
    BackendID backendId;
    Exception e;

    this(BackendID backendId, Exception e) {
        this.backendId = backendId;
        this.e = e;
    }
}

abstract class LoggingBackend {
    BackendID id;      /// BackendID of the backend.
    Tid tid;           /// Tid of the backend thread.
    string shortTitle; /// Short title for the sidebar
    string longTitle;  /// Longer title for the headerbar subtitle

    /**
     * Abstract method for subclasses to override. Start reading lines from the
     * log source and send them back to the main thread.
     */
    abstract void readLines();

    /**
     * Create a new logging backend.
     * Params:
     *     _shortTitle = A shorter title for the sidebar.
     *     _longTitle  = A longer title for the headerbar subtitle.
     */
    this(string _shortTitle, string _longTitle) {
        this.id = newId++;
        this.shortTitle = _shortTitle;
        this.longTitle = _longTitle;
    }

    /**
     * Spawn the logging backend as a new thread and start reading lines.
     */
    void start() {
        this.tid = spawn((shared LoggingBackend self) {
            try {
                (cast(LoggingBackend) self).readLines();
            } catch (Exception e) {
                ownerTid.send(cast(shared) BeventException(self.id, e));
            }
        }, cast(shared) this);
    }

    /**
     * Callback for when a new log line is read
     * Params:
     *      line = a line of chomped log output.
     */
    void newLogLineCallback(string line) {
        ownerTid.send(cast(shared) BeventNewLogLines(this.id, line));
    }
}
