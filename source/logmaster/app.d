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

void main(string[] args)
{
    //writeln("Logmaster logging library");
    //auto l = new UnixStreamBackend(stdin);
    //l.readLines();

    /*
     * Create window
     */
    Main.init(args);
    auto window = new MainWindow("Logmaster");
    window.setDefaultSize(1000, 600);
    auto header = new HeaderBar();
    header.setTitle("Logmaster");
    header.setShowCloseButton(true);
    window.setTitlebar(header);

    // List of data
    auto listStore = new ListStore([GType.STRING]);
    foreach(int i; 0..10) {
        TreeIter iter = listStore.createIter();
        listStore.setValue(iter, 0, "log message");
    }

    // Add a table for displaying logs
    auto logviewer = new TreeView();
    auto column = new TreeViewColumn("message", new CellRendererText(), "text", 0);
    column.setResizable(true);
    column.setMinWidth(200);
    logviewer.appendColumn(column);
    logviewer.setModel(listStore);

    window.add(logviewer);

    window.showAll();
    Main.run();
}

// unbuffer npm start | logmaster -
// logmaster -- npm start
// logmaster file.txt -- npm start
// logmaster /var/log/mongodb/mongod.log
// logmaster --docker ab4a

