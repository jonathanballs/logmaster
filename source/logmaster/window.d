module logmaster.window;

import std.concurrency;
import std.stdio;
import core.thread;

import gtk.Button;
import gtk.CellRendererText;
import gtk.HeaderBar;
import gtk.FileChooserDialog;
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

import logmaster.backend;
import logmaster.constants;
import logmaster.logviewer;


// Reminder for jonny when u get back
// You were just in the middle of implementing threading code
// The problem is the thread ids
// Do it again carefully and make sure that the right ids are in the right place

/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    LoggingBackend[] backends;
    LogViewer[Tid] logViewers;

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
        openLogButton.addOnClicked(&onOpenFileClicked);
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

    void onOpenFileClicked(Button b) {
        auto fileDialog = new FileChooserDialog("Open Log", this, FileChooserAction.OPEN);
        auto res = fileDialog.run();
        if (res == ResponseType.OK) {
            auto filename = fileDialog.getFilename();
            this.openFile(filename);
        }
        fileDialog.hide();
    }

    void openFile(string filename) {
        import logmaster.backends.file;
        auto backend = new FileBackend(filename);
        this.addBackend(backend);
    }

    void openStream(File f, string streamName) {
        import logmaster.backends.stream;
        auto backend = new UnixStreamBackend(stdin, streamName);
        this.addBackend(backend);
    }

    bool receiveBackendEvents(Widget w, FrameClock f) {
        while(receiveTimeout(-1.msecs,
            (shared BeventNewLogLines event) {
                auto logViewer = this.logViewers[cast(Tid)event.tid];
                TreeIter iter = logViewer.listStore.createIter();
                logViewer.listStore.setValue(iter, 0, event.line);
            }
        )) {}

        return true;
    }

    void addBackend(LoggingBackend backend) {
        backend.start();
        this.backends ~= backend;
        auto logViewer = new LogViewer();
        logViewers[backend.tid] = logViewer;

        logViewerStack.addTitled(logViewer, backend.title, backend.title);
        sidebar.setStack(logViewerStack);
        this.showAll();
    }
}
