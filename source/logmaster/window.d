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

import logmaster.backendthread;
import logmaster.constants;
import logmaster.logviewer;


// Reminder for jonny when u get back
// You were just in the middle of implementing threading code
// The problem is the thread ids
// Do it again carefully and make sure that the right ids are in the right place

/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    BackendThread[] backends;
    LogViewer[ThreadID] logViewers;

    HeaderBar headerBar;
    Paned paned;
    StackSidebar sidebar;
    Stack logViewerStack;

    /// Sets up a new logmaster window with sidebar, panes, logview etc.
    this() {
        // Initialise
        super(Constants.appName);
        this.setDefaultSize(Constants.appDefaultWidth,
            Constants.appDefaultHeight);

        // Header bar
        headerBar = new HeaderBar();
        headerBar.setTitle(Constants.appName);
        headerBar.setShowCloseButton(true);
        auto openLogButton = new Button("Open Log");
        headerBar.packStart(openLogButton);
        this.setTitlebar(headerBar);

        // Paned view
        paned = new Paned(Orientation.HORIZONTAL);

        // Add the sidebar and sidebar stack
        sidebar = new StackSidebar();
        logViewerStack = new Stack();

        sidebar.setStack(logViewerStack);
        sidebar.setSizeRequest(Constants.sidebarDefaultWidth, -1);
        paned.pack1(sidebar, false, false);
        paned.pack2(logViewerStack, true, true);
        this.addTickCallback(&this.receiveBackendEvents);

        this.add(paned);
    }

    void openFile(string filename) {
        import logmaster.backends.file;
        auto backend = new FileBackend(filename);
        BackendThread backendThread = new BackendThread(backend);
        this.addBackend(backendThread);
    }

    void openStream(File f, string streamName) {
        import logmaster.backends.stream;
        auto backend = new UnixStreamBackend(stdin, streamName);
        BackendThread backendThread = new BackendThread(backend);
        this.addBackend(backendThread);
    }

    bool receiveBackendEvents(Widget w, FrameClock f) {
        while(receiveTimeout(-1.msecs,
            (shared BeventNewLogLines event) {
                auto logViewer = this.logViewers[cast(ThreadID)event.threadId];
                TreeIter iter = logViewer.listStore.createIter();
                logViewer.listStore.setValue(iter, 0, event.line);
            }
        )) {}

        return true;
    }

    void addBackend(BackendThread backend) {
        // Create 
        backend.start();
        this.backends ~= backend;
        auto logViewer = new LogViewer();
        logViewers[backend.id] = logViewer;
        writeln(logViewers);

        logViewerStack.addTitled(logViewer,
            backend.backend.title,
            backend.backend.title);
    }
}
