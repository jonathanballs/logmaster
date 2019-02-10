module logmaster.backends.file;

import std.algorithm;
import std.concurrency;
import std.conv;
import std.datetime.stopwatch;
import std.file;
import std.path;
import std.range;
import std.stdio;
import std.string;
import core.time;

import logmaster.backend;
import logmaster.backendevents;

private class FileLogLines : LogLines {
    File f;
    ulong[] lineOffsets;
    string filename;

    this(string filename) { this.filename = filename; }

    override ulong opDollar() { return lineOffsets.length; }
    override LogLine opIndex(long i) {
        if (!f.isOpen()) {
            f.open(this.filename);
        }

        long startOffset = lineOffsets[i];
        long endOffset;

        if (i+1 < length()-1) {
            endOffset = lineOffsets[i + 1] - 1;
        } else {
            endOffset = f.size();
        }

        assert(startOffset <= endOffset);

        if (startOffset == endOffset) {
            return LogLine(i, "");
        }

        ubyte[] buffer;
        buffer.length = endOffset - startOffset;

        f.seek(startOffset);
        auto data = f.rawRead(buffer);
        return LogLine(i, data.assumeUTF);
    }
    override ulong length() { return lineOffsets.length; }
}

class FileBackend : LoggingBackend {
    FileLogLines _lines;
    string filename;

    this(string filePath)
    {
        super(filePath, baseName(filePath));
        filename = filePath;
        this._lines = new FileLogLines(filename);
    }

    override ulong start() { return 0; }
    override ulong end() { return lines.length - 1; }
    override LogLines lines() {
        return _lines;
    }

    override void handleEvent(Variant v) {
        if (v.type == typeid(EventIndexingProgress)) {
            auto e = v.get!EventIndexingProgress;
            this.indexingPercentage = e.progressPercentage;
            this.onIndexingProgress.emit(this.indexingPercentage);
            this._lines.lineOffsets ~= e.lineOffsets[0..e.lineOffsetsLength];
            this.onNewLines.emit();
        } else {
            import std.stdio : writeln;
            writeln("ERR: can't handle this event");
        }
    }

    private Tid tid;
    override void spawnIndexingThread() {
        this.tid = spawn((string filename, BackendID backendID) {
            try {
                auto indexer = new FileIndexer(filename, backendID);
                indexer.start();
            } catch (Exception e) {
                writeln(e);
            }
        }, cast(shared) this.filename, this.id);
    }

}

private class FileIndexer {
    string filename;
    BackendID backendID;

    File f;
    ulong[] lineOffsets;

    this(string filename, BackendID backendID) {
        this.filename = filename;
        this.backendID = backendID;
    }


    void start() {
        StopWatch s;
        s.start();
        ulong bufNum;
        f = File(filename);

        foreach (ubyte[] buf; f.byChunk(new ubyte[BUFSIZ])) {
            auto offset = (bufNum * BUFSIZ); // Index after the nl char

            foreach (j, b; buf) {
                if (b == '\n') {
                    lineOffsets ~= offset + j + 1;
                }
            }

            // Send updates to front end
            if (!(bufNum % 1000)) {
                sendLineOffsets();
            }

            bufNum++;
        }
        sendLineOffsets();

        this.sendEvent(EventIndexingProgress(1.0));
        s.stop();
    }

    protected void sendLineOffsets() {
        auto e = EventIndexingProgress();
        e.progressPercentage = (cast(float) f.tell() / f.size());

        // Split the new indexes into chunks
        import std.range: chunks;
        foreach (chunk; lineOffsets.chunks(e.lineOffsets.length)) {
            e.lineOffsets[0..chunk.length] = chunk;
            e.lineOffsetsLength = cast(short) chunk.length;
            this.sendEvent(e);
        }
        this.lineOffsets = [];
    }

    protected void sendEvent(T)(T event) {
        BackendEvent b;
        b.backendID = this.backendID;
        b.payload = event;
        send(ownerTid(), b);
    }
}
