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

enum IndexesSize = 4000;

struct IndexingProgress {
    /// Float between 0 and 100
    float progressPercentage;
    ulong[IndexesSize] newIndexes;

    bool isFinished;
}

class FileBackend : LoggingBackend {

    string filename;
    File f;
    /**
     * Create a new instance of a File Log.
     * Params:
     *      filePath = Path of the file to open
     */
    this(string filePath) {
        super(filePath, baseName(filePath));
        filename = filePath;
    }

    __gshared ulong[] lineOffsets;

    static void indexingThread(string filename) {
        StopWatch s;
        s.start();
        ulong bufNum;
        File f = File(filename);

        lineOffsets = [0];
        foreach (ubyte[] buf; f.byChunk(new ubyte[BUFSIZ])) {

            auto offset = (bufNum*BUFSIZ); // Index after the nl char

            if ((bufNum % 1000) == 0) {
                this.indexingPercentage = (100 * cast(float)offset) / f.size();
            }

            foreach (j, b; buf) {
                if (b == '\n') {
                    lineOffsets ~= offset + j + 1;
                }
            }
            bufNum++;
        }

        this.indexingPercentage = 100.0;
        s.stop();
        writeln(s.peek.total!"seconds");

        // Send message to main thread
        writeln("Finished");
    }
	
	// InputRange!string opSlice(long i, long j) {
	// 	return [];
	// }

    override bool isIndexed() {
        return this.indexingPercentage == 100.0;
    }

    void receiveEvents() {
        while(receiveTimeout(-1.msecs,
        (Variant v) {
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
        long endOffset = lineOffsets[i+1] - 1;

        writeln(startOffset);
        writeln(endOffset);

        writeln("length of offset: ", endOffset - startOffset);

        ubyte[] buffer;
        buffer.length = endOffset - startOffset;

        f.seek(startOffset);
        auto data = f.rawRead(buffer);
        return data.assumeUTF;
    }

    private Tid tid;
    void spawnIndexingThread() {
        this.tid = spawn(cast(shared)&FileBackend.indexingThread, this.filename);
    }
}
