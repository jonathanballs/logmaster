import std.typecons : Typedef;
import std.range : InputRange;

// General thoughts:
// All data should be on main thread. Other threads operate and amend this data.
// We will have to think about safety: send updates via message, to main thread
// who will handle data accordingly.

// Still thinking about:
// Use of ranges is very useful. Should look into ref as well. Iterating over
// the array should be done in place.

// The log is randomly accessible in byte form. e.g. files, sshfs, over
// http. NOT for papertrail
interface RawLogData {
    ulong size(); // Optional
    ubyte opIndex(ulong i);

    // From char to char
    ubyte[] opSlice(ulong i, ulong j);
    ulong opDollar();

    // Make this range
    ubyte[] byChunk();
}

// NB: LogInterface should be fine for general lookup (if isIndexed is true)
// Many log types will have special features (which is good) but those features
// should be implemented by sub interfaces or classes. This is a data processing
// interface and does not contain meta data or implementation details for the
// app. This should be fully modular so it is portable (for both mac and linux
// as well as a potential "remote daemon" to process logs on a server)
abstract class LogInterface {

    /// Percentage that implexing has completed
    /// Will be negative if not available (i.e for unknown log sizes)
    /// Will be 100.0 if complete
    __gshared float indexingPercentage;

    // Log array indexing and slicing.
    string opIndex(long i);
    // InputRange!string opSlice(long i, long j);
    ulong opDollar();

    // Has an index been created of _all_ lines. I.e. have line number
    // from beginning to end. and can be fully queried by lineId.
    bool isIndexed();

    // First log id. Depending on implementation, may not be zero. Useful for
    // going to the start of the log. E.g. for kubernetes, log may start at
    // negative. TODO: review this: could get kubernetes to start at 1. as tail
    // functions are running. Don't want to 
    ulong start();

    // Last log id. Depending on implementation, may be zero. Useful for going
    // to the end of the log.
    ulong end();
}

// Log interface where logs are just streamed to the cache. There is
// no source of truth that can be queried. Everything is cached and the
// cache is queried for data. Probably the simplest to implement. Cache
// may need to become more advanced (i.e. cache to disk or smth). Everything
// will be indexed as it arrives. Should be implementable with a single
// overriden method per class?
// Superclass for: ptrace, stdin, subprocess
abstract class StreamedLog : LogInterface {

    // Cache of all log data in order
    protected ubyte[] cache;
    protected ulong[] lineOffsets;

    // Blocking. Returns data as it arrives.
    private InputRange!(ubyte[]) byChunk();
}

// A log which already exists and must be analysed. Much more complex because
// the user may want to explore log before it has finished. Once indexed, it
// behaves like a normal log. This log must be able to provide head and tail
// for when it has not fully be indexed.
// File, Kubernetes
abstract class ExternalLogBackend : LogInterface {
    // Return tail (final lines)... How does this work for 
    string[] tail(ulong numLines);
    string[] head(ulong numLines);
}

struct IndexingProgress {
    /// Float between 0 and 100
    float progressPercentage;

    ulong[] newIndexes;

    bool isFinished;
}
