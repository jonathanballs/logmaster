/*
 * Unix stream backend. Predominantly used for logs arriving via stdin
 */

module logmaster.unixStreamBackend;

import std.stdio;
import std.string;
import std.file;
import std.conv : to;

import core.stdc.stdlib;
import core.sys.posix.fcntl;

extern(C) int grantpt(int fd);
extern(C) int unlockpt(int fd);
extern(C) char *ptsname(int fd);

void checkErr(int errNum) {
    if (errNum != 0) {
        throw new Exception("Error!");
    }
}

class UnixStreamBackend {
    string[] backlog;
    File stream;

    this(File stdStream) {
        this.stream = stdStream;
    }

    int numReadLines() {
        return cast(int) this.backlog.length;
    }

    void readLines() {
        /*
         * Attach stream to a pty
         */
        auto f = open("/dev/ptmx", O_RDWR);
        checkErr(grantpt(f));
        checkErr(unlockpt(f));
        char* name = ptsname(f);
        writeln("PTS slave is " ~ to!string(name));

        while (!stdin.eof) {
            auto line = stdin.readln().chomp();
            backlog ~= line;
            writeln(backlog.length, " ", line);
        }
    }
}

