module logmaster.backends.subprocess;

import std.string;
import std.concurrency;
import std.process;
import std.stdio;

import logmaster.backends;
import logmaster.backendevents;
import logmaster.backends.stream;

class SubprocessBackend : StreamBackend {
    string[] command;
    Tid tid;

    this(string[] command, string title = "Unix Stream") {
        super(title, title);
        this.command = command;
        this.indexingPercentage = 1.0;
    }

    override void spawnIndexingThread() {
        this.tid = spawn((shared string[] commands, BackendID backendID) {
            try {
                auto indexer = new SubprocessIndexer(cast(string[]) commands, backendID);
                indexer.start();
            } catch (Exception e) {
                writeln(e);
            }
        }, cast(shared) this.command, this.id);
    }
}

private class SubprocessIndexer {
    string[] command;
    BackendID backendID;

    this(string[] command, BackendID backendID) {
        this.backendID = backendID;
        this.command = command;
    }

    void start() {
        auto pipes = pipeProcess(this.command, Redirect.stdout);
        foreach (line; pipes.stdout.byLine) {
            import std.conv: to;
            this.sendEvent(EventNewLine(line.to!string));
        }
    }

    protected void sendEvent(T)(T event) {
        BackendEvent b;
        b.backendID = this.backendID;
        b.payload = event;
        send(ownerTid(), b);
    }
}
