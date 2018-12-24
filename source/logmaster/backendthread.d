module logmaster.backendthread;

import logmaster.backends.stream;

import core.thread;
import std.concurrency;

class BackendThread : Thread {
    /// Logging backend used
    UnixStreamBackend backend;

    this(UnixStreamBackend _backend) {
        this.backend = _backend;
        this.backend.tid = thisTid;
        super(&run);
    }

    private void run() {
        backend.readLines();
    }
}
