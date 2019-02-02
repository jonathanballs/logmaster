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
        return this.indexingPercentage == 100.0;
    }

    // Receive events from the frontend
    protected void receiveEvents() {
        while (receiveTimeout(-1.msecs, (Variant v) {
                writeln(v);
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

        writeln(startOffset);
        writeln(endOffset);

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
        this.tid = spawn((shared FileBackend self) {
            try {
                (cast(FileBackend) self).indexingThread();
            } catch (Exception e) {
                EventException event = EventException(e);
                (cast(FileBackend)self).sendEvent(event);
            }
        }, cast(shared) this);
    }

    void indexingThread() {
        StopWatch s;
        s.start();
        ulong bufNum;
        File f = File(filename);

        lineOffsets = [0];
        foreach (ubyte[] buf; f.byChunk(new ubyte[BUFSIZ])) {
            auto offset = (bufNum * BUFSIZ); // Index after the nl char

            if (!(bufNum % 1000)) {
                this.indexingPercentage = cast(
                        float) offset / f.size();
                auto e = EventIndexingProgress(this.indexingPercentage);
                this.sendEvent(e);
            }

            foreach (j, b; buf) {
                if (b == '\n') {
                    lineOffsets ~= offset + j + 1;
                }
            }
            bufNum++;
        }

        this.sendEvent(EventIndexingProgress(1.0));

        s.stop();
    }
}
