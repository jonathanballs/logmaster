module logmaster.window;

import gtk.CellRendererText;
import gtk.HeaderBar;
import gtk.ListStore;
import gtk.MainWindow;
import gtk.Paned;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.StackSidebar;
import gtk.Stack;

import gdk.FrameClock;

import std.concurrency;
import std.stdio;
import core.thread;


import glib.Timeout;

import logmaster.constants;

/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    ListStore logs;

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

        // Add the sidebar and sidebar stack
        auto sidebar = new StackSidebar();
        auto sidebarStack = new Stack();

        sidebar.setStack(sidebarStack);
        paned.pack1(sidebar, true, true);
        paned.pack2(sidebarStack, true, true);

        // List of data
        logs = new ListStore([GType.STRING]);

        // Add a table for displaying logs
        auto logviewer = new TreeView();
        auto column = new TreeViewColumn("message", new CellRendererText(), "text", 0);
        column.setResizable(true);
        column.setMinWidth(200);
        logviewer.appendColumn(column);
        logviewer.setModel(logs);
        sidebarStack.addTitled(logviewer, "stdin", "stdin");

        // Add an example log
        TreeIter iter = logs.createIter();
        logs.setValue(iter, 0, "No logs yet");

        this.addTickCallback(&this.receiveBackendEvents);

        this.add(paned);
    }

    bool receiveBackendEvents(Widget w, FrameClock f) {
        receiveTimeout(-1.msecs,
            (string s) {
                TreeIter iter = logs.createIter();
                logs.setValue(iter, 0, s);
            }
        );

        return true;
    }
}
