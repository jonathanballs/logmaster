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
        progressBar = new ProgressBar();

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
        import std.stdio;
        if (this.backend.indexingPercentage < 1.0) {
            progressBar = new ProgressBar();
            progressBar.setHalign(GtkAlign.CENTER);
            progressBar.setValign(GtkAlign.CENTER);
            this.add(progressBar);
            // progressBar.setFraction(this.backend.indexingPercentage);
        } else {
            this.add(treeView);
        }
    }

    void handleEvent(Variant v) {
        // Pass event on
        this.backend.handleEvent(v);

        this.progressBar.setFraction(backend.indexingPercentage);
        if (backend.indexingPercentage == 1.0) {
            this.removeAll();
            this.add(treeView);
            this.showAll();
        }
    }
}
