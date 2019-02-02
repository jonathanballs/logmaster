import std.array : split;
import std.algorithm;
import std.conv;
import std.format;
import std.getopt;
import std.range;
import std.regex;
import std.string;
import std.stdio;

import gtk.Main;
import gtk.Widget;

import logmaster.window;
// import logmaster.backends.file;
// import logmaster.backends.stream;

int main(string[] args)
{
    auto opts = parseArgs(args);

    if (opts.detach) {
        writeln("ERR: detached mode is not supported");
        return 0;
    }

    /*
     * Create window
     */
    Main.init(args);
    auto window = new LogmasterWindow();

    /*
     * Open files passed via command line
     */
    foreach (filename; opts.files) {
        // Check if filename is actually stdin
        if (filename == "-") {
            auto stdinName = getStdinName();
            auto stdinShortName = stdinName.split(' ')[0];
            // window.addBackend(new UnixStreamBackend(stdin, stdinShortName, stdinName));
        } else {
            // window.addBackend(new FileBackend(filename));
        }
    }

    /**
     * Start program passed as subprocess to 
     */
    // TODO


    // Open these automatically during development just to be quick
    debug {
        // if (!opts.files.canFind(["-"])) {
        //     window.addBackend(new UnixStreamBackend(stdin, "stdin"));
        // }
        // window.addBackend(new FileBackend("/var/log/pacman.log"));
    }

    window.showAll();
    window.addOnDestroy(delegate void(Widget w){
        Main.quit();
        // TODO: Try to quit gracefully
        import core.stdc.stdlib : exit;
        exit(0);
    });
    Main.run();
    return 0;
}

struct LogmasterOpts {
    /// Run logmaster as daemon (return to console)
    bool detach;

    /// Command to run as subprocess
    string[] command;

    /// Files to open. `stdin` will be `"-""`
    string[] files;
}

/**
 * Argument parsing
 * Params:
 *      args = string array of arguments including program name as passed to
 *             main
 */
LogmasterOpts parseArgs(string[] args) {
    LogmasterOpts opts;

    // Command to run as subprocess
    auto commandSplit = args.findSplit(["--"]);
    if (!commandSplit[2].empty) {
        opts.command = array(commandSplit[2]);
        args = array(commandSplit[0]);
    }

    // Filter out stdin because "-" causes getopt to throw exception
    if (args.canFind("-")) {
        opts.files ~= "-";
        args = args.filter!"a != \"-\"".array;
    }

    // Check if receiving from stdin
    auto helpInfo = getopt(
        args,
        "d|detach", &opts.detach
    );
    opts.files ~= args[1..$]; // Everything that isn't the program name

    if (helpInfo.helpWanted) {
        writeln("help!!!");

        import core.stdc.stdlib : exit;
        exit(0);
    }

    return opts;
}

/**
 * Uses procfs in order to find what program/file stdin is coming from.
 */
string getStdinName() {
    version(linux) {
        import core.thread : getpid;
        import std.file : readLink, dirEntries, SpanMode;
        auto linkName = readLink(format!"/proc/%d/fd/0"(getpid()));
        if (linkName.startsWith("pipe")) {
            foreach (string pidPath; dirEntries("/proc/", SpanMode.shallow)) {
                try {
                    string stdoutLink = readLink(pidPath ~ "/fd/1");
                    if(stdoutLink == linkName) {
                        import std.file : read;
                        auto cmd = (cast(const(ubyte)[]) read(pidPath ~ "/cmdline"))
                            .split(0)
                            .map!(a => a.assumeUTF());

                        if (cmd.length > 2 && cmd[0] == "tclsh" && cmd[1] == "/usr/bin/unbuffer") {
                            cmd = cmd[2..$];
                        }

                        return cmd
                            .joiner(" ")
                            .to!string;
                    }
                } catch (Exception e) {
                    // Ignore if can't access etc.
                }
            }
        }
        return "stdin";
    } else {
        return "stdin";
    }
}
