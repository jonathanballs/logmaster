module logmaster.backendevents;

import std.variant;
import logmaster.backends : BackendID;

struct BackendEvent {
    BackendID backendID;
    Variant payload;
}

struct EventIndexingProgress {
    float progressPercentage;
    ulong[4000] lineOffsets; // Needs to be static array to be shared
    short lineOffsetsLength;
}

struct EventException {
    Exception e;
}
