module logmaster.backendevents;

import std.variant;
import logmaster.backend : BackendID;

struct BackendEvent {
    BackendID backendID;
    Variant payload;
}

struct EventIndexingProgress {
    float progressPercentage;
    ulong[4000] lineOffets; // Needs to be static array to be shared
}

struct EventException {
    Exception e;
}
