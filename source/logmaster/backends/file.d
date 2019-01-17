module logmaster.backends.file;

import std.stdio;
import std.file;
import std.string;
import std.array;
import std.concurrency;
import std.path : baseName;
import logmaster.backend;

class FileBackend : LoggingBackend {
    string filename;

    this(string filename) {
        super(baseName(filename), filename);
        this.filename = filename;
    }

    override void readLines() {
        string fileContents = readText(this.filename);
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
