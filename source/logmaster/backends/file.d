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

enum IndexesSize = 4000;

class FileBackend : LoggingBackend {

    string filename;
    File f;
    /**
     * Create a new instance of a File Log.
     * Params:
     *      filePath = Path of the file to open
     */
    this(string filePath)
    {
        super(filePath, baseName(filePath));
        filename = filePath;
    }

    ulong[] lineOffsets;

    override bool isIndexed() {
        return this.indexingPercentage == 1.0;
    }

    // Receive events from the frontend
    protected void receiveEvents() {
        while (receiveTimeout(-1.msecs, (Variant v) {
                writeln("Received event ", v);
            })) {}
    }

    override ulong opDollar() {
        return lineOffsets.length;
    }

    override ulong start() {
        return 0;
    }

    override ulong end() {
        return lineOffsets.length - 1;
    }

    override void handleEvent(Variant v) {
        if (v.type == typeid(EventIndexingProgress)) {
            auto e = v.get!EventIndexingProgress;
            this.indexingPercentage = e.progressPercentage;
            this.lineOffsets ~= e.lineOffsets[0..e.lineOffsetsLength];
        } else {
            import std.stdio : writeln;
            writeln("ERR: can't handle this event");
        }
    }

    // Return log line istruct IndexingProgress {
    /// Float between 0 and 100
    float progressPercentage;
    ulong[IndexesSize] newIndexes;

    bool isFinished;

    override string opIndex(long i) {
        if (!f.isOpen()) {
            f.open(this.filename);
        }
        long startOffset = lineOffsets[i];
        long endOffset = lineOffsets[i + 1] - 1;

        writeln("length of offset: ",
                endOffset - startOffset);

        ubyte[] buffer;
        buffer.length = endOffset - startOffset;

        f.seek(startOffset);
        auto data = f.rawRead(buffer);
        return data.assumeUTF;
    }

    private Tid tid;
    override void spawnIndexingThread() {
        this.tid = spawn((string filename, BackendID backendID) {
            try {
                auto indexer = new FileIndexer(filename, backendID);
                indexer.indexingThread();
            } catch (Exception e) {
                writeln(e);
            }

            // try {
            //     (cast(FileBackend) self).indexingThread();
            // } catch (Exception e) {
            //     writeln(e);
            //     EventException event = EventException(e);
            //     (cast(FileBackend)self).sendEvent(event);
            // }
        }, cast(shared) this.filename, this.id);
    }

}

private class FileIndexer {
    string filename;
    BackendID backendID;

    this(string filename, BackendID backendID) {
        this.filename = filename;
        this.backendID = backendID;
    }

    ulong[] lineOffsets;

    void indexingThread() {
        StopWatch s;
        s.start();
        ulong bufNum;
        File f = File(filename);
        lineOffsets = [0];

        foreach (ubyte[] buf; f.byChunk(new ubyte[BUFSIZ])) {
            auto offset = (bufNum * BUFSIZ); // Index after the nl char

            foreach (j, b; buf) {
                if (b == '\n') {
                    lineOffsets ~= offset + j + 1;
                }
            }

            // Send updates to front end
            if (!(bufNum % 1000)) {
                auto e = EventIndexingProgress();
                e.progressPercentage = (cast(float) offset + buf.length) / f.size();

                // Split the new indexes into chunks
                import std.range: chunks;
                foreach (chunk; lineOffsets.chunks(e.lineOffsets.length)) {
                    e.lineOffsets[0..chunk.length] = chunk;
                    e.lineOffsetsLength = cast(short) chunk.length;
                    this.sendEvent(e);
                }
                lineOffsets = [];
            }

            bufNum++;
        }
        this.sendEvent(EventIndexingProgress(1.0));
        s.stop();
    }

    protected void sendEvent(T)(T event) {
        BackendEvent b;
        b.backendID = this.backendID;
        b.payload = event;
        send(ownerTid(), b);
    }
}
