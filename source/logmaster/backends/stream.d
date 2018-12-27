/*
 * Unix stream backend. Predominantly used for logs arriving via stdin
 */

module logmaster.backends.stream;

import std.stdio;
import std.string;
import std.file;
import std.conv : to;
import std.concurrency;

import core.stdc.stdlib;
import core.sys.posix.fcntl;

import logmaster.backend;

// extern(C) int grantpt(int fd);
// extern(C) int unlockpt(int fd);
// extern(C) char *ptsname(int fd);

void checkErr(int errNum) {
    if (errNum != 0) {
        throw new Exception("Error!");
    }
}

class UnixStreamBackend : LoggingBackend {
    File stream;

    this(File stdStream, string _title = "unix stream") {
        super(_title);
        this.stream = stdStream;
    }

    override void readLines() {
        /*
         * Attach stream to a pty
         */
        // auto f = open("/dev/ptmx", O_RDWR);
        // checkErr(grantpt(f));
        // checkErr(unlockpt(f));
        // char* name = ptsname(f);
        // writeln("PTS slave is " ~ to!string(name));

        while (!stdin.eof) {
            string line = this.stream.readln().chomp();
            this.newLogLineCallback(line);
        }
    }
}

