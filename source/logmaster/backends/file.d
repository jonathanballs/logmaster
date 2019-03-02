module logmaster.backends.file;

import std.algorithm;
import std.concurrency;
import std.conv;
import std.datetime.stopwatch;
import std.file;
import std.path;
import std.parallelism;
import std.mmfile;
import std.range;
import std.stdio;
import std.string;
import core.atomic;
import core.time;
import core.sys.posix.sys.stat;

import logmaster.backends;
import logmaster.backendevents;

private struct EventIndexingProgress {
    float progressPercentage;
    ulong[4000] lineOffsets; // Needs to be static array to be shared
    short lineOffsetsLength;
}

private class FileLogLines : LogLines {
    File f;
    ulong[] lineOffsets;
    string filename;

    this(string filename) { this.filename = filename; }

    override ulong length() { return lineOffsets.length; }
    override ulong opDollar() { return this.length; }
    override LogLine opIndex(long i) {
        File f;
        f.open(this.filename);

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
        import std.utf : validate;
        try {
            string s = data.assumeUTF;
            validate(s);
            return LogLine(i, s);
        } catch (Exception e) {
            writeln("Couldn't parse ", data);
            return LogLine(i, "");
        }
    }
    override int opApply(int delegate(LogLine) dlg) {
        int result = 0;
        foreach (i; 0..length()) {
            result = dlg(this[i]);
            if (result) return result;
        }
        return 0;
    }

    ulong _longestLineLength;
    override ulong longestLineLength() { return _longestLineLength; }
}

class FileBackend : LoggingBackend {
    FileLogLines _lines;
    string filename;

    this(string filePath) {
        super(filePath, baseName(filePath));
        filename = filePath;
        this._lines = new FileLogLines(filename);
    }

    override LogLines lines() {
        return _lines;
    }

    override void handleEvent(Variant v) {
        if (v.type == typeid(EventIndexingProgress)) {
            auto e = v.get!EventIndexingProgress;
            this.indexingPercentage = e.progressPercentage;
            this.onIndexingProgress.emit(this.indexingPercentage);
            this._lines.lineOffsets ~= e.lineOffsets[0..e.lineOffsetsLength];

            // Calculate the longest line
            auto startIndex = _lines.lineOffsets.length - e.lineOffsetsLength;
            if (_lines.lineOffsets.length != e.lineOffsetsLength) startIndex--;
            import std.range : slide;
            import std.algorithm : max;
            foreach(pair; _lines.lineOffsets[startIndex..$].slide(2)) {
                _lines._longestLineLength = max(_lines.longestLineLength, pair[1] - pair[0]);
            }


            this.onNewLines.emit();
        } else {
            super.handleEvent(v);
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
    MmFile file;
    Tid mainTid;

    this(string filename, BackendID backendID) {
        this.filename = filename;
        this.backendID = backendID;
        this.mainTid = ownerTid();
    }

    void start() {
        file = new MmFile(this.filename);
        auto bufsize = BUFSIZ;

        size_t[][] offsets;
        if (file.length == 0) return;

        offsets.length = 1 + (file.length - 1) / bufsize;
        offsets[0] = [0];

        StopWatch s;
        s.start();

        shared(ulong) numComplete;

        foreach (i, ref offsetList; parallel(offsets)) {
            auto start = i*BUFSIZ;
            auto end = min((i+1)*BUFSIZ, file.length);
            foreach(j; start..end) {
                if (file[j] == '\n') {
                    offsetList ~= j+1;
                }
            }

            numComplete.atomicOp!"+="(1);
            if ((numComplete % 100) == 0) {
                float progress = cast(float) (numComplete * BUFSIZ) / file.length;
                sendEvent(EventIndexingProgress(progress));
            }
        }

        sendLineOffsets(offsets.joiner().array);

        s.stop();
    }

    protected void sendLineOffsets(ulong[] lineOffsets) {
        auto e = EventIndexingProgress();

        // Split the new indexes into chunks
        import std.range: chunks;
        long bufNum;
        foreach (chunk; lineOffsets.chunks(e.lineOffsets.length)) {
            e.lineOffsets[0..chunk.length] = chunk;
            e.lineOffsetsLength = cast(short) chunk.length;
            e.progressPercentage = cast(float) lineOffsets.length / (bufNum++*e.lineOffsets.length);
            this.sendEvent(e);
        }
    }

    protected void sendEvent(T)(T event) {
        BackendEvent b;
        b.backendID = this.backendID;
        b.payload = event;
        send(mainTid, b);
    }
}
