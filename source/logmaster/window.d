module logmaster.window;

import std.concurrency;
import std.stdio;
import core.thread;

import gtk.Button;
import gtk.CellRendererText;
import gtk.HeaderBar;
import gtk.FileChooserDialog;
import gtk.Image;
import gtk.Label;
import gtk.ListStore;
import gtk.HBox;
import gtk.MainWindow;
import gtk.Notebook;
import gtk.ScrolledWindow;
import gtk.StockItem;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gdk.FrameClock;
import gdk.Keysyms;
import glib.Timeout;

import logmaster.backend;
import logmaster.constants;
import logmaster.logviewer;


/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    LoggingBackend[] backends;
    LogViewer[BackendID] logViewers;

    Notebook notebook;
    HeaderBar headerBar;

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

        // Create the notebook
        this.notebook = new Notebook();
        this.notebook.setTabPos(GtkPositionType.LEFT);
        this.addTickCallback(&this.receiveBackendEvents);

        // Keyboard shortcut listener
        this.addOnKeyPress(&this.onKeyPress);
        this.add(notebook);
    }

    /*
     * Keyboard Shortcuts
     */
    bool onKeyPress(GdkEventKey* g, Widget w) {

        // If control key pressed
        if (g.state & ModifierType.CONTROL_MASK) {
            switch(g.keyval) {
            case Keysyms.GDK_o:
                this.onOpenFileClicked(new Button());
                break;
            case Keysyms.GDK_w:
                auto currentPage = cast(LogViewer) notebook.getNthPage(notebook.getCurrentPage);
                this.closeBackend(currentPage.backendId);
                break;
            case Keysyms.GDK_Tab:
                auto nextPageNumber = notebook.getCurrentPage() + 1;
                if (nextPageNumber < notebook.getNPages()) {
                    notebook.setCurrentPage(nextPageNumber);
                } else {
                    notebook.setCurrentPage(0);
                }
                break;
            default:
                break;
            }
        }
        return true;
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

        // Don't recieve events if backends haven't been created
        if (this.backends.length == 0) {
            return true;
        }

        while(receiveTimeout(-1.msecs,
            (shared BeventNewLogLines event) {
                auto logViewer = this.logViewers[event.backendId];
                TreeIter iter = logViewer.listStore.createIter();
                logViewer.listStore.setValue(iter, 0, event.line);
            }
        )) {}

        return true;
    }

    void closeBackend(BackendID backendId) {
        writeln("Closing backend ", backendId);
        // 1. End the process
        // 2. Remove tab
        // 3. Release associated data
    }

    void addBackend(LoggingBackend backend) {
        backend.start();
        this.backends ~= backend;
        auto logViewer = new LogViewer(backend.id);
        logViewers[backend.id] = logViewer;

        // Create the label
        class CloseButton : Button {
            BackendID backendId;
            LogmasterWindow window;
            this(BackendID bId, LogmasterWindow window) {
                super();
                this.window = window;
                this.backendId = bId;
                this.addOnClicked(&this.onClick);
            }

            void onClick(Button b) {
                this.window.closeBackend(this.backendId);
            }
        }

        auto label = new Label(backend.title);
        label.setXalign(0.0);
        auto image = new Image(StockID.CLOSE, GtkIconSize.MENU);
        auto button = new CloseButton(backend.id, this);
        button.setRelief(GtkReliefStyle.NONE);
        button.setImage(image);

        auto hbox = new HBox(false, 5);
        hbox.packStart(label, true, true, 0);
        hbox.packEnd(button, false, true, 0);

        auto pageNum = this.notebook.appendPage(logViewer, hbox);
        hbox.showAll();
        logViewer.showAll();
        this.showAll();
        this.notebook.setCurrentPage(pageNum);
    }
}
