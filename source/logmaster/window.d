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
import logmaster.logviewer;

/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    BackendThread[] backends;
    LogViewer logViewer;

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

        logViewer = new LogViewer();
        sidebarStack.addTitled(logViewer, "stdin", "stdin");

        // Add an example log
        TreeIter iter = logViewer.listStore.createIter();
        logViewer.listStore.setValue(iter, 0, "No logs yet");

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
                TreeIter iter = logViewer.listStore.createIter();
                logViewer.listStore.setValue(iter, 0, s);
            }
        );

        return true;
    }
}
