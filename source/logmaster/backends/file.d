module logmaster.backends.file;

import std.stdio;
import std.file;
import std.string;
import std.array;
import logmaster.backend;

class FileBackend : LoggingBackend {
    string fileContents;

    this(string filename) {
        super(filename);
        fileContents = readText(filename);
    }

    override void readLines() {
        foreach (line; fileContents.split('\n')) {
            this.newLogLineCallback(line);
        }
    }
}
