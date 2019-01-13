module logmaster.backends.file;

import std.stdio;
import std.file;
import std.string;
import std.array;
import std.concurrency;
import std.path : baseName;
import logmaster.backend;

class FileBackend : LoggingBackend {
    string fileContents;

    this(string filename) {
        super(baseName(filename),filename);
        fileContents = readText(filename);
    }

    override void readLines() {
        foreach (line; fileContents.split('\n')) {
            this.newLogLineCallback(line);
        }

        while(true) {
            bool shouldExit = false;
            import core.time: msecs;
            receiveTimeout(35.msecs,
                (BeventExitThread e) {
                    shouldExit = true;
                },
            );

            if (shouldExit) {
                return;
            }
        }
    }
}
