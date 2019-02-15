module logmaster.backendevents;

import std.variant;
import logmaster.backends : BackendID;

struct BackendEvent {
    BackendID backendID;
    Variant payload;
}

struct EventException {
    Exception e;
}
