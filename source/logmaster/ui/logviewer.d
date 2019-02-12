module logmaster.ui.logviewer;

import std.concurrency;
import std.variant;
import std.stdio;
import core.thread;

import cairo.Context;
import gdk.FrameClock;
import gdk.Rectangle;
import gtk.Adjustment;
import gtk.Alignment;
import gtk.Box;
import gtk.CellRendererText;
import gtk.CellRendererText;
import gtk.Layout;
import gtk.ProgressBar;
import gtk.Revealer;
import gtk.ScrolledWindow;
import gtk.SearchBar;
import gtk.SearchEntry;
import gtk.TreeIter;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Widget;

import logmaster.backend;
import logmaster.backendevents;

class LogViewer : Box {
    // Meta
    LoggingBackend backend;

    // Loading progress
    Alignment progressAlignment;
    ProgressBar progressBar;

    // Log view
    ScrolledWindow scrolledWindow;
    Layout layout;
    private enum rowHeight = 20;

    this(LoggingBackend backend) {
        super(GtkOrientation.VERTICAL, 20);
        this.backend = backend;
        this.backend.onNewLines.connect(() {
            if (this.layout) {
                this.layout.setSize(100, rowHeight * cast(uint) this.backend.lines.length);
                this.queueDraw();
            }
        });

        /**
         * Pack the scrolled layout.
         */
        if (backend.indexingPercentage == 1.0) {
            this.packScrolledLayout();
            this.showAll();
            return;
        }

        /**
         * Otherwise pack the progress bar
         */
        this.progressBar = new ProgressBar();
        progressBar = new ProgressBar();
        progressBar.setHalign(GtkAlign.CENTER);
        progressBar.setValign(GtkAlign.CENTER);
        progressBar.setFraction(this.backend.indexingPercentage);
        this.packStart(progressBar, true, true, 0);
        this.backend.onIndexingProgress.connect((float p) {
            if (p < 1.0) {
                progressBar.setFraction(p);
            } else {
                if (this.layout) return;
                this.remove(progressBar);
                this.progressBar = null;
                this.packStart(constructSearchBar(), false, true, 0);
                this.packScrolledLayout();
                this.showAll();
            }
        });
    }

    SearchBar searchBar;
    Revealer revealer;
    SearchEntry searchEntry;
    private Revealer constructSearchBar() {
        searchBar = new SearchBar();
        revealer = new Revealer();
        searchEntry = new SearchEntry();

        searchEntry.setHexpand(true);
        revealer.setHexpand(true);
        revealer.add(searchBar);
        searchBar.add(searchEntry);
        searchBar.setSearchMode(true);
        revealer.setRevealChild(true);
        return revealer;
    }

    void toggleSearchBar() {
        revealer.setRevealChild(!revealer.getRevealChild());
    }

    private void packScrolledLayout() {
        this.setSpacing(0);
        this.layout = new Layout(null, null);
        layout.setSize(100, rowHeight * cast(uint) this.backend.lines.length);
        layout.addOnDraw(&this.onDraw);
        this.scrolledWindow = new ScrolledWindow();
        scrolledWindow.add(layout);
        this.packStart(scrolledWindow, true, true, 0);
    }

    /**
     * Draw the backend lines
     */
    bool onDraw(Scoped!Context c, Widget w) {
        Adjustment vAdjustment = layout.getVadjustment();
        uint firstLineNumber = cast(uint) vAdjustment.getValue() / rowHeight;
        uint firstLineY = firstLineNumber * rowHeight - cast(uint) vAdjustment.getValue();

        if (backend.lines.length == 0) return true;

        auto viewportSize = this.getLayoutAllocation(layout);

        foreach (i; 0..(viewportSize.height / rowHeight) + 2) {
            if (firstLineNumber + i > backend.end()) break;

            string message = backend.lines[firstLineNumber + i].message;
            uint y = firstLineY + i*rowHeight;

            GdkRectangle rect = GdkRectangle(0, y,
                viewportSize.width, this.rowHeight);

            CellRendererText renderer = new CellRendererText();
            renderer.setProperty("text", message);
            renderer.setProperty("family", "Monospace");
            renderer.render(c, w, &rect, &rect, GtkCellRendererState.INSENSITIVE);
        }

        return true;
    }

    private GdkRectangle getLayoutAllocation(Layout layout) {
        GdkRectangle allocatedSize;
        layout.getAllocation(allocatedSize);
        return allocatedSize;
    }
}
