module logmaster.backendthread;

import logmaster.backend;

import core.thread;
import std.concurrency;

class Bevent {
    ThreadID threadId;
}

class BeventNewLogLines : Bevent {
    string line;
    this(ThreadID _threadId, string _line) {
        this.threadId = _threadId;
        this.line = _line;
    }
}

class BeventException : Bevent {
    Exception exception;
}

class BackendThread : Thread {
    /// Logging backend used
    LoggingBackend backend;

    this(LoggingBackend _backend) {
        this.backend = _backend;
        super(&run);
        this.backend.tid = this.id;
    }

    private void run() {
        backend.readLines();
    }
}
