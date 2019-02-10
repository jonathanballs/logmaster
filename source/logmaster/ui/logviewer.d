module logmaster.ui.logviewer;

import std.concurrency;
import std.variant;
import std.stdio;
import core.thread;
import gdk.FrameClock;
import gtk.Alignment;
import gtk.CellRendererText;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.ProgressBar;
import cairo.Context;
import gdk.Rectangle;
import gtk.Adjustment;
import gtk.CellRendererText;
import gtk.Layout;
import gtk.Widget;

import logmaster.backend;
import logmaster.backendevents;

class LogViewer : ScrolledWindow {
    // Meta
    LoggingBackend backend;

    // Loading progress
    Alignment progressAlignment;
    ProgressBar progressBar;

    // Log view
    Layout layout;
    private enum rowHeight = 20;

    this(LoggingBackend backend) {
        this.backend = backend;
        this.backend.onNewLines.connect(() {
            if (this.layout) {
                this.layout.setSize(100, rowHeight * cast(uint) this.backend.lines.length);
                this.queueDraw();
            }
        });

        // If already indexed then just show the backend otherwise show a
        // loading counter.
        if (backend.indexingPercentage == 1.0) {
            this.layout = createLayout();
            this.add(layout);
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
                    if (this.layout) return;
                    this.removeAll();
                    this.layout = createLayout();
                    this.add(layout);
                }
            });
        }
    }

    private Layout createLayout() {
        auto layout = new Layout(null, null);
        layout.setSize(100, rowHeight * cast(uint) this.backend.lines.length);
        layout.addOnDraw(&this.onDraw);
        layout.showAll();
        return layout;
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

    void handleEvent(Variant v) {
        // Pass event on
        this.backend.handleEvent(v);
    }
}
