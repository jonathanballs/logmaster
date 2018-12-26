module logmaster.window;

import std.concurrency;
import std.stdio;
import core.thread;

import gtk.Button;
import gtk.CellRendererText;
import gtk.HeaderBar;
import gtk.ListStore;
import gtk.MainWindow;
import gtk.Paned;
import gtk.ScrolledWindow;
import gtk.Stack;
import gtk.StackSidebar;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gdk.FrameClock;
import glib.Timeout;

import logmaster.backends.stream;
import logmaster.backendthread;
import logmaster.constants;

/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    ListStore logs;

    BackendThread[] backends;

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
        auto openLogButton = new Button("Open Log");
        header.packStart(openLogButton);
        this.setTitlebar(header);

        // Paned view
        auto paned = new Paned(Orientation.HORIZONTAL);

        // Add the sidebar and sidebar stack
        auto sidebar = new StackSidebar();
        auto sidebarStack = new Stack();

        sidebar.setStack(sidebarStack);
        sidebar.setSizeRequest(Constants.sidebarDefaultWidth, -1);
        paned.pack1(sidebar, false, false);
        paned.pack2(sidebarStack, true, true);

        // List of data
        logs = new ListStore([GType.STRING]);

        // Add a table for displaying logs
        auto scrolledWindow = new ScrolledWindow();
        auto logviewer = new TreeView();
        logviewer.getSelection().setMode(GtkSelectionMode.NONE);
        auto cellRendererText = new CellRendererText();
        cellRendererText.setProperty("family", "Monospace");
        cellRendererText.setProperty("size-points", 10);

        // Add column to logviewer
        auto column = new TreeViewColumn("message", cellRendererText, "text", 0);
        column.setResizable(true);
        column.setMinWidth(200);
        logviewer.appendColumn(column);
        logviewer.setModel(logs);
        scrolledWindow.add(logviewer);
        sidebarStack.addTitled(scrolledWindow, "stdin", "stdin");

        // Add an example log
        TreeIter iter = logs.createIter();
        logs.setValue(iter, 0, "No logs yet");

        this.addTickCallback(&this.receiveBackendEvents);

        this.add(paned);
    }

    void openStream(File f, string streamName) {
        auto backend = new UnixStreamBackend(stdin, "stdin");
        BackendThread backendThread = new BackendThread(backend);
        this.addBackend(backendThread);
    }

    void addBackend(BackendThread backend) {
        backend.start();
        this.backends ~= backend;
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
