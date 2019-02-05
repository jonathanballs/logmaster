module logmaster.lazytreeview;

import std.stdio;
import std.conv;
import cairo.Context;
import gtk.Adjustment;
import gtk.Layout;
import gtk.Widget;
import gdk.Rectangle;
import gtk.CellRendererText;

import logmaster.backend;

class LazyTreeView : Layout {
    LoggingBackend backend;

    uint rowHeight = 30;

    uint allocatedWidth = 100;
    uint allocatedHeight = 100;

    public this(LoggingBackend backend) {
        this.backend = backend;
        super(null, null);
        this.setSize(100, rowHeight * cast(uint) this.backend.opDollar());
        this.addOnSizeAllocate(&this.onSizeAllocate);
        this.addOnDraw(&this.onDraw);
    }

    void onSizeAllocate(GtkAllocation* allocation, Widget widget) {
        this.allocatedWidth = allocation.width;
        this.allocatedHeight = allocation.height;
    }

    bool onDraw(Scoped!Context c, Widget w) {
        Adjustment vAdjustment = this.getVadjustment();
        uint firstLineNumber = cast(uint) vAdjustment.getValue() / rowHeight;
        uint firstLineY = firstLineNumber * rowHeight - cast(uint) vAdjustment.getValue();

        writeln(allocatedHeight);

        foreach (i; 0..(allocatedHeight / rowHeight) + 2) {
            string message = backend[firstLineNumber + i].message;
            uint y = firstLineY + i*rowHeight;
            GdkRectangle rect = GdkRectangle(0, y,
                this.allocatedWidth, this.rowHeight);
            CellRendererText renderer = new CellRendererText();
            renderer.setProperty("text", message);
            renderer.render(c, w, &rect, &rect, GtkCellRendererState.INSENSITIVE);
        }

        return true;
    }
}
