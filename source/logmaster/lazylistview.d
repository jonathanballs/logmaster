module logmaster.lazylistview;

import cairo.Context;
import gtk.DrawingArea;
import gtk.ScrollableIF;
import gtk.Widget;
import gtk.IconView;


class LazyListView : DrawingArea {
	/**
	 * Sets our main struct and passes it to the parent class.
	 */
	public this ()
	{
		super(1000, 3000);
        this.addOnDraw(&this.onDraw);
	}

    bool onDraw(Context c, Widget w) {
        c.setSourceRgb(1.0, 0.0, 0.0);
        c.moveTo(300, 300);
        c.showText("Hello world");
        return true;
    }
}
