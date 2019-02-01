module logmaster.logviewer;

import std.concurrency;
import core.thread;
import gdk.FrameClock;
import gtk.CellRendererText;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;

import logmaster.backend;
import logmaster.lazytreemodel;

class LogViewer : ScrolledWindow {

    // Meta
    string shortTitle;
    BackendID backendId;

    // Implementation
    TreeView treeView;
    LazyTreeModel model;

    this(BackendID bid) {
        this.backendId = bid;

        /*
         * Create tree view and list store
         */
        this.treeView = new TreeView();
        this.treeView.getSelection().setMode(GtkSelectionMode.NONE);

        this.model = new LazyTreeModel();

        treeView.setModel(this.model);

        TreeViewColumn col;
        CellRendererText renderer;
        col = new TreeViewColumn();
		renderer  = new CellRendererText();
		col.packStart(renderer, true);
		col.addAttribute(renderer, "text", CustomListColumn.Name);
		col.setTitle("Name");
		treeView.appendColumn(col);

		col = new TreeViewColumn();
		renderer  = new CellRendererText();
		col.packStart(renderer, true);
		col.addAttribute(renderer, "text", CustomListColumn.YearBorn);
		col.setTitle("Year Born");
		treeView.appendColumn(col);

        /*
         * Set default message saying that there aren't any logs yet
         */

        this.add(treeView);
    }
}
