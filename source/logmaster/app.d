import std.stdio;
import std.getopt;

import gtk.Main;
import gtk.MainWindow;
import gtk.HeaderBar;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.ListStore;
import gtk.CellRendererText;
import gtk.ListStore;
import gtk.TreeIter;

import logmaster.unixStreamBackend;
import logmaster.logmasterwindow;

void main(string[] args)
{
    // TODO: Argument parsing

    /*
     * Create window
     */
    Main.init(args);
    auto window = new LogmasterWindow();
    window.showAll();
    Main.run();
}

// unbuffer npm start | logmaster -
// logmaster -- npm start
// logmaster file.txt -- npm start
// logmaster /var/log/mongodb/mongod.log
// logmaster --docker ab4a

