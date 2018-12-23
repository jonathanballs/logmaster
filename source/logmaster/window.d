module logmaster.window;

import gtk.CellRendererText;
import gtk.HeaderBar;
import gtk.ListStore;
import gtk.MainWindow;
import gtk.Paned;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.TreeViewColumn;

import logmaster.constants;

/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    /// Sets up a new logmaster window with sidebar, panes, logview etc.
    this() {
        // Initialise
        super(Constants.appName);
        this.setDefaultSize(Constants.appDefaultWidth,
            Constants.appDefaultHeight);

        // Header bar
        auto header = new HeaderBar();
        header.setTitle(Constants.appName);
        header.setShowCloseButton(true);
        this.setTitlebar(header);

        // Paned view
        auto paned = new Paned(Orientation.HORIZONTAL);

        // List of data
        auto listStore = new ListStore([GType.STRING]);
        foreach(int i; 0..10) {
            TreeIter iter = listStore.createIter();
            listStore.setValue(iter, 0, "log message");
        }

        // Add a table for displaying logs
        auto logviewer = new TreeView();
        auto column = new TreeViewColumn("message", new CellRendererText(), "text", 0);
        column.setResizable(true);
        column.setMinWidth(200);
        logviewer.appendColumn(column);
        logviewer.setModel(listStore);

        this.add(logviewer);
    }
}
