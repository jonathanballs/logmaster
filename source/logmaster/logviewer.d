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

import logmaster.backend;

class LogViewer : ScrolledWindow {

    // Meta
    string shortTitle;
    BackendID backendId;

    // Implementation
    TreeView treeView;
    ListStore listStore;

    this(BackendID bid) {
        this.backendId = bid;

        /*
         * Create tree view and list store
         */
        this.treeView = new TreeView();
        this.treeView.getSelection().setMode(GtkSelectionMode.NONE);
        this.listStore = new ListStore([GType.STRING]);
        treeView.setModel(listStore);

        /*
         * Text rendering
         */
        auto cellRendererText = new CellRendererText();
        cellRendererText.setProperty("family", "Monospace");
        cellRendererText.setProperty("size-points", 10);

        /*
         * Add Column to tree view for messages
         */
        auto column = new TreeViewColumn("message", cellRendererText, "text", 0);
        column.setResizable(true);
        column.setMinWidth(200);
        this.treeView.appendColumn(column);

        /*
         * Set default message saying that there aren't any logs yet
         */
        // TreeIter iter = this.listStore.createIter();
        // this.listStore.setValue(iter, 0, "No logs yet");

        this.add(treeView);
    }
}
