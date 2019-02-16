module logmaster.backends;

import std.typecons : Typedef;
import std.range : InputRange;
import std.concurrency;
import std.typecons;
import std.variant;

import logmaster.backendevents;
import logmaster.signals;
import logmaster.filters;
public import logmaster.loglines;

alias BackendID = Typedef!(int);
private static BackendID availableID = 0;

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
    LogLines lines();
    /// Percentage that implexing has completed Will be negative if not
    /// available (i.e for unknown log sizes) Will be 100.0 if complete
    float indexingPercentage = 0.0;
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

    /**
     * Called when the indexing thread may be started
     */
    void spawnIndexingThread();

    /**
     * Handle backend events
     */
    void handleEvent(Variant v);

    /**
     * Filtering. Just one filter for now but will have to mange multiple ones
     * in the future.
     */
    RegexFilter filter;
    void setFilter(RegexFilter filter) {
        this.filter = filter;
        if (filter)
            filter.spawnIndexingThread();
    }
}
