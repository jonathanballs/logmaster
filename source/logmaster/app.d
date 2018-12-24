import std.stdio;
import std.getopt;
import std.concurrency;

import gtk.Main;

import logmaster.backends.stream;
import logmaster.backendthread;
import logmaster.window;

void main(string[] args)
{
    // TODO: Argument parsing

    /*
     * Create window
     */
    Main.init(args);
    auto window = new LogmasterWindow();

    auto backend = new UnixStreamBackend(stdin);
    auto backendThread = new BackendThread(backend).start();

    window.showAll();
    Main.run();
}

// unbuffer npm start | logmaster -
// logmaster -- npm start
// logmaster log.txt -- npm start
// logmaster /var/log/mongodb/mongod.log
// logmaster --docker ab4a
