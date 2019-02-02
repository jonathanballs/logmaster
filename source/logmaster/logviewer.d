module logmaster.logviewer;

import std.concurrency;
import std.variant;
import core.thread;
import gdk.FrameClock;
import gtk.Alignment;
import gtk.CellRendererText;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.ProgressBar;

import logmaster.lazytreemodel;
import logmaster.backend;
import logmaster.backendevents;

class LogViewer : ScrolledWindow {

    // Meta
    string shortTitle;
    LoggingBackend backend;

    // Implementation
    TreeView treeView;
    LazyTreeModel model;

    Alignment progressAlignment;
    ProgressBar progressBar;

    this(LoggingBackend backend) {
        this.backend = backend;

        /*
         * Create tree view and list store
         */
        this.treeView = new TreeView();
        this.treeView.getSelection().setMode(GtkSelectionMode.NONE);

        this.model = new LazyTreeModel();

        treeView.setModel(this.model);

        foreach (column; this.model.getTreeViewColumns) {
            treeView.appendColumn(column);
        }

        /*
         * Set default message saying that there aren't any logs yet
         */

        if (this.backend.indexingPercentage < 100.0) {
            progressBar = new ProgressBar();
            progressBar.setHalign(GtkAlign.CENTER);
            progressBar.setValign(GtkAlign.CENTER);
            this.add(progressBar);
            progressBar.setFraction(this.backend.indexingPercentage);
        } else {
            this.add(treeView);
        }
    }

    void handleEvent(Variant v) {
        if (v.type == typeid(EventIndexingProgress)) {
            auto e = v.get!EventIndexingProgress;
            this.progressBar.setFraction(e.progressPercentage);
        } else {
            import std.stdio : writeln;
            writeln("ERR: can't handle this event");
        }
    }
}
