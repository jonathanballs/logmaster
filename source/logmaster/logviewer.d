module logmaster.logviewer;

import std.concurrency;
import std.variant;
import core.thread;
import gdk.FrameClock;
import gtk.Alignment;
import gtk.CellRendererText;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.ProgressBar;

import logmaster.lazytreeview;
import logmaster.backend;
import logmaster.backendevents;

class LogViewer : ScrolledWindow {

    // Meta
    string shortTitle;
    LoggingBackend backend;

    // Implementation
    LazyTreeView treeView;

    Alignment progressAlignment;
    ProgressBar progressBar;

    this(LoggingBackend backend) {
        this.backend = backend;
        this.progressBar = new ProgressBar();

        /*
         * Set the progress bar
         */
        progressBar = new ProgressBar();
        progressBar.setHalign(GtkAlign.CENTER);
        progressBar.setValign(GtkAlign.CENTER);
        this.add(progressBar);
        progressBar.setFraction(this.backend.indexingPercentage);
    }

    void handleEvent(Variant v) {
        // Pass event on
        this.backend.handleEvent(v);

        this.progressBar.setFraction(backend.indexingPercentage);
        if (backend.indexingPercentage == 1.0) {

            if (this.treeView) return;

            this.treeView = new LazyTreeView(this.backend);

            this.removeAll();
            this.add(treeView);
            this.showAll();
        }
    }
}
