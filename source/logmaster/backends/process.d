module logmaster.backends.process;

import logmaster.backend;

class ProcessBackend : LoggingBackend {
    string[] command;
    this(string[] command) {
        // TODO: longTitle includes args
        super(command[0], command[0]);
    }
}
