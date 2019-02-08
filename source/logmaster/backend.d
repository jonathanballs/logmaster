module logmaster.backend;

import std.typecons : Typedef;
import std.range : InputRange;
import std.concurrency;
import std.typecons;
import std.variant;

import logmaster.backendevents;
import logmaster.signals;

alias BackendID = Typedef!(int);
private static BackendID availableID = 0;

alias LogLine = Tuple!(ulong, "lineID", string, "message");

// NB: LoggingBackend should be fine for general lookup (if isIndexed is true)
// Many log types will have special features (which is good) but those features
// should be implemented by sub interfaces or classes. This is a data processing
// interface and does not contain meta data or implementation details for the
// app. This should be fully modular so it is portable (for both mac and linux
// as well as a potential "remote daemon" to process logs on a server)
abstract class LoggingBackend {
    string shortTitle;
    string longTitle;
    BackendID id;

    Signal!() onNewLines = new Signal!();
    Signal!(float) onIndexingProgress = new Signal!(float);

    /**
     * Create a new instance of logging backend.
     */
    this(string longTitle, string shortTitle) {
        this.shortTitle = shortTitle;
        this.longTitle = longTitle;
        this.id = availableID++;
    }

    /// Percentage that implexing has completed Will be negative if not
    /// available (i.e for unknown log sizes) Will be 100.0 if complete
    float indexingPercentage = 0.0;

    // Log array indexing and slicing.
    LogLine opIndex(long i);
    // InputRange!string opSlice(long i, long j);
    ulong opDollar();

    // First log id. Depending on implementation, may not be zero. Useful for
    // going to the start of the log. E.g. for kubernetes, log may start at
    // negative. TODO: review this: could get kubernetes to start at 1. as tail
    // functions are running. Don't want to 
    ulong start();

    // Last log id. Depending on implementation, may be zero. Useful for going
    // to the end of the log.
    ulong end();

    // Backends should be responsible for managing their own threads.
    void spawnIndexingThread();

    // Handle a backend event.
    void handleEvent(Variant v);

}

// Log interface where logs are just streamed to the cache. There is no source
// of truth that can be queried. Everything is cached and the cache is queried
// for data. Probably the simplest to implement. Cache may need to become more
// advanced (i.e. cache to disk or smth). Everything will be indexed as it
// arrives. Should be implementable with a single overriden method per class?
// Superclass for: ptrace, stdin, subprocess
abstract class StreamedLog : LoggingBackend {

    this(string shortTitle, string longTitle) {
        super(shortTitle, longTitle);
    }

    // Cache of all log data in order
    protected ubyte[] cache;
    protected ulong[] lineOffsets;

    // Blocking. Returns data as it arrives.
    private InputRange!(ubyte[]) byChunk();
}

// A log which already exists and must be analysed. Much more complex because
// the user may want to explore log before it has finished. Once indexed, it
// behaves like a normal log. This log must be able to provide head and tail for
// when it has not fully be indexed. File, Kubernetes
abstract class ExternalLogBackend : LoggingBackend {

    this(string shortTitle, string longTitle) {
        super(shortTitle, longTitle);
    }
    // Return tail (final lines)... How does this work for 
    string[] tail(ulong numLines);
    string[] head(ulong numLines);
}
