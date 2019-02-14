module logmaster.backends.unixstream;

import std.concurrency;
import std.file;
import std.stdio;
import std.string;
import std.variant;
import core.thread;
import core.time;

import logmaster.backends;
import logmaster.backends.stream;
import logmaster.backendevents;

class UnixStreamBackend : StreamBackend {
    File stream;
    Tid tid;

    this(File stream, string title = "Unix Stream") {
        super(title, title);
        this.stream = stream;
        this.indexingPercentage = 1.0;
    }

    override void spawnIndexingThread() {
        this.tid = spawn((shared File* stream, BackendID backendID) {
            try {
                auto indexer = new UnixStreamIndexer(cast(File) *stream, backendID);
                indexer.start();
            } catch (Exception e) {
                writeln(e);
            }
        }, cast(shared) &this.stream, this.id);
    }
}

private class UnixStreamIndexer {
    File stream;
    BackendID backendID;

    this(File stream, BackendID backendID) {
        this.backendID = backendID;
        this.stream = stream;
    }

    void start() {
        while (!stdin.eof) {
            EventNewLine newLine = EventNewLine(this.stream.readln().chomp());
            sendEvent(newLine);
        }
    }

    protected void sendEvent(T)(T event) {
        BackendEvent b;
        b.backendID = this.backendID;
        b.payload = event;
        send(ownerTid(), b);
    }
}
