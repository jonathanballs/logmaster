import std.stdio;
import std.getopt;
import std.concurrency;

import gtk.Main;
import gtk.Widget;
import logmaster.window;

void main(string[] args)
{
    // TODO: Argument parsing

    /*
     * Create window
     */
    Main.init(args);
    auto window = new LogmasterWindow();

    // TODO find out source of stdin
    window.openStream(stdin, "stdin");
    window.openFile("/var/log/pacman.log");

    window.showAll();
    window.addOnDestroy(delegate void(Widget w){
        Main.quit();
        // TODO: Try to quit gracefully
        import core.stdc.stdlib : exit;
        exit(0);
    });
    Main.run();
    return;
}

// unbuffer npm start | logmaster -
// logmaster -- npm start
// logmaster log.txt -- npm start
// logmaster /var/log/mongodb/mongod.log
// logmaster --docker ab4a
