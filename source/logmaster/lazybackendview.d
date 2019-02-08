module logmaster.lazybackendview;

import std.stdio;
import std.conv;
import cairo.Context;
import gtk.Adjustment;
import gtk.Layout;
import gtk.Widget;
import gdk.Rectangle;
import gtk.CellRendererText;

import logmaster.backend;

class LazyBackendView : Layout {
    LoggingBackend backend;

    uint rowHeight = 20;

    uint allocatedWidth = 100;
    uint allocatedHeight = 100;

    public this(LoggingBackend backend) {
        super(null, null);
        this.backend = backend;
        this.setSize(100, rowHeight * cast(uint) this.backend.opDollar());
        this.addOnSizeAllocate(&this.onSizeAllocate);
        this.addOnDraw(&this.onDraw);

        // Redraw on new lines
        this.backend.onNewLines.connect(() {
            this.setSize(100, rowHeight * cast(uint) this.backend.opDollar());
            this.queueDraw();
        });
    }

    void onSizeAllocate(GtkAllocation* allocation, Widget widget) {
        this.allocatedWidth = allocation.width;
        this.allocatedHeight = allocation.height;
    }

    void onNewLines() {
    }

    bool onDraw(Scoped!Context c, Widget w) {
        Adjustment vAdjustment = this.getVadjustment();
        uint firstLineNumber = cast(uint) vAdjustment.getValue() / rowHeight;
        uint firstLineY = firstLineNumber * rowHeight - cast(uint) vAdjustment.getValue();

        if (backend.opDollar() == 0) return true;

        foreach (i; 0..(allocatedHeight / rowHeight) + 2) {
            if (firstLineNumber + i > backend.end()) break;

            string message = backend[firstLineNumber + i].message;
            uint y = firstLineY + i*rowHeight;
            GdkRectangle rect = GdkRectangle(0, y,
                this.allocatedWidth, this.rowHeight);
            CellRendererText renderer = new CellRendererText();
            renderer.setProperty("text", message);
            renderer.setProperty("family", "Monospace");
            renderer.render(c, w, &rect, &rect, GtkCellRendererState.INSENSITIVE);
        }

        return true;
    }
}
