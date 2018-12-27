module logmaster.backend;

import std.concurrency;
import core.thread;

import logmaster.backendthread;

abstract class LoggingBackend {
    ThreadID tid;
    string title;
    abstract void readLines();

    this(string _title) {
        this.title = _title;
    }

    void newLogLineCallback(string line) {
        const BeventNewLogLines event = new BeventNewLogLines(tid, line);
        thisTid.send(cast(shared) event);
    }
}
