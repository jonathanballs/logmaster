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

        if (this.backend.indexingPercentage == 1.0) {
            this.treeView = new LazyTreeView(this.backend);
            this.add(treeView);
        } else {
            this.progressBar = new ProgressBar();
            /*
            * Set the progress bar
            */
            progressBar = new ProgressBar();
            progressBar.setHalign(GtkAlign.CENTER);
            progressBar.setValign(GtkAlign.CENTER);
            progressBar.setFraction(this.backend.indexingPercentage);
            this.add(progressBar);

            this.backend.onIndexingProgress.connect((float p) {
                if (p < 1.0) {
                    progressBar.setFraction(p);
                } else {
                    if (this.treeView) return;
                    this.removeAll();
                    this.treeView = new LazyTreeView(this.backend);
                    this.add(treeView);
                    this.showAll();
                }
            });
        }

    }

    void handleEvent(Variant v) {
        // Pass event on
        this.backend.handleEvent(v);
    }
}
