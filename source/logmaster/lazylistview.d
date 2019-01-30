module logmaster.lazylistview;
import std.stdio;

import cairo.Context;
import gtk.DrawingArea;
import gtk.ScrollableIF;
import gtk.ScrollableT;
import gtk.Widget;
import gtk.IconView;
import gtk.c.types;
import std.experimental.logger : trace;

import gobject.Signals;

class LazyListView : DrawingArea, ScrollableIF {

    Adjustment hAdjustment;
    Adjustment vAdjustment;
    GtkScrollablePolicy hScrollPolicy = GtkScrollablePolicy.NATURAL;
    GtkScrollablePolicy vScrollPolicy = GtkScrollablePolicy.NATURAL;
	
	public this ()
	{
		// super(null, false);
        super();
        hAdjustment = new Adjustment(0, 0, 2000, 20, 1000, 1000);
        vAdjustment = new Adjustment(0, 0, 2000, 20, 1000, 1000);
        // this.addOnDraw(&this.onDraw);
	}

    bool onDraw(Context c, Widget w) {
        return true;
    }

    GtkScrollable* getScrollableStruct(bool transferOwnership= false) {
		if (transferOwnership)
			ownedRef = false;
        return cast(GtkScrollable*)this.gtkWidget;
    }

    override void* getStruct() {
        return super.getStruct();
    }

    public bool getBorder(out Border border) {
        return true;
    }

    public Adjustment getHadjustment() {
        return hAdjustment;
    }

    public GtkScrollablePolicy getHscrollPolicy() {
        return hScrollPolicy;
    }

    public Adjustment getVadjustment() {
        return vAdjustment;
    }

    public GtkScrollablePolicy getVscrollPolicy() {
        return vScrollPolicy;
    }

    public void setHadjustment(Adjustment _hAdjustment) {
        hAdjustment = _hAdjustment;
        writeln(_hAdjustment);
    }

    public void setHscrollPolicy(GtkScrollablePolicy policy) {
        hScrollPolicy = policy;
    }

    public void setVadjustment(Adjustment vadjustment) {
        writeln(vadjustment);
        vAdjustment = vadjustment;
    }

    public void setVscrollPolicy(GtkScrollablePolicy policy) {
        vScrollPolicy = policy;
    }
}



	/**
	 * Sets our main struct and passes it to the parent class.
	 */
