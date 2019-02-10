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

class LogLines {
    LogLine opIndex(long i) { return LogLine(0, "hello"); }
    ulong opDollar() { return this.length; }
    ulong length() { return 0; }
}

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

    Signal!() onNewLines = new Signal!();
    Signal!(float) onIndexingProgress = new Signal!(float);

    LogLines lines();

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
