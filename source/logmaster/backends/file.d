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
            foreach(pair; _lines.lineOffsets[startIndex..$-1].slide(2)) {
                _lines._longestLineLength = max(_lines.longestLineLength, pair[1] - pair[0]);
            }


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
        ulong bufNum;
        f = File(filename);
        lineOffsets ~= 0;

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
