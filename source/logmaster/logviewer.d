module logmaster.logviewer;

import std.concurrency;
import core.thread;
import gdk.FrameClock;
import gtk.CellRendererText;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;

class LogViewer : ScrolledWindow {
    TreeView treeView;
    ListStore listStore;

    this() {
        /*
         * Create tree view
         */

        this.treeView = new TreeView();
        this.treeView.getSelection().setMode(GtkSelectionMode.NONE);

        auto cellRendererText = new CellRendererText();
        cellRendererText.setProperty("family", "Monospace");
        cellRendererText.setProperty("size-points", 10);

        // List of data
        listStore = new ListStore([GType.STRING]);

        // Add column to treeview for log messages
        auto column = new TreeViewColumn("message", cellRendererText, "text", 0);
        column.setResizable(true);
        column.setMinWidth(200);
        treeView.appendColumn(column);
        treeView.setModel(listStore);

        // Add a log saying there are no logs
        TreeIter iter = this.listStore.createIter();
        this.listStore.setValue(iter, 0, "No logs yet");

        this.addTickCallback(&this.receiveBackendEvents);

        this.add(treeView);
    }

    bool receiveBackendEvents(Widget w, FrameClock f) {
        while(receiveTimeout(-1.msecs,
            (string s) {
                TreeIter iter = this.listStore.createIter();
                this.listStore.setValue(iter, 0, s);
            }
        )) {}

        return true;
    }
}
