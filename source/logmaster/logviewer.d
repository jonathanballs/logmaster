module logmaster.logviewer;

import gtk.CellRendererText;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.TreeView;
import gtk.TreeViewColumn;

class LogViewer : ScrolledWindow {
    TreeView treeView;
    ListStore listStore;

    this() {
        /*
         * Create tree view
         */

        this.treeView = new TreeView();
        this.treeView.getSelection().setMode(GtkSelectionMode.NONE);

        auto cellRendererText = new CellRendererText();
        cellRendererText.setProperty("family", "Monospace");
        cellRendererText.setProperty("size-points", 10);

        // List of data
        listStore = new ListStore([GType.STRING]);

        // Add column to treeview for log messages
        auto column = new TreeViewColumn("message", cellRendererText, "text", 0);
        column.setResizable(true);
        column.setMinWidth(200);
        treeView.appendColumn(column);
        treeView.setModel(listStore);

        this.add(treeView);
    }
}
