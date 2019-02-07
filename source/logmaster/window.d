module logmaster.window;

import std.concurrency;
import std.format;
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

import logmaster.constants;
import logmaster.logviewer;
import logmaster.backend;
import logmaster.backendevents;


/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    LoggingBackend[BackendID] backends;
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
        this.notebook.addOnSwitchPage(&this.onChangeLogviewer);

        // Handle backend events every tick
        this.addTickCallback(&this.receiveBackendEvents);

        // Keyboard shortcut listener
        this.addOnKeyPress(&this.onKeyPress);
        this.add(notebook);
    }

    /**
     * Set the long title as a subtitle when opening a backend
     */
    void onChangeLogviewer(Widget w, uint pageNum, Notebook n) {
        auto backendId = (cast(LogViewer)notebook.getNthPage(pageNum)).backend.id;
        this.headerBar.setSubtitle(backends[backendId].longTitle);
    }

    /**
     * Keyboard Shortcuts
     */
    bool onKeyPress(GdkEventKey* g, Widget w) {

        // If CTRL key pressed
        if (g.state & ModifierType.CONTROL_MASK) {
            switch(g.keyval) {
            // Open file dialog
            case Keysyms.GDK_o:
                this.onOpenFileClicked(new Button());
                break;
            // Close current tab/window
            case Keysyms.GDK_w:
                if (notebook.getNPages() == 0) {
                    writeln("Exit the program");
                } else {
                    auto currentPage = cast(LogViewer) notebook.getNthPage(notebook.getCurrentPage);
                    this.removeBackend(currentPage.backend.id);
                }
                break;
            // Cycle tabs
            case Keysyms.GDK_Tab:
                auto nextPageNumber = notebook.getCurrentPage() + 1;
                if (nextPageNumber < notebook.getNPages()) {
                    notebook.setCurrentPage(nextPageNumber);
                } else {
                    notebook.setCurrentPage(0);
                }
                break;
            // Cycle tabs backwards. Not sure why have to handle it like this...
            case Keysyms.GDK_ISO_Left_Tab:
                int prevPageNumber = notebook.getCurrentPage() - 1;
                if (prevPageNumber < 0 ) {
                    notebook.setCurrentPage(notebook.getNPages() - 1);
                } else {
                    notebook.setCurrentPage(prevPageNumber);
                }
                break;
            default:
                break;
            }
        }
        return true;
    }

    /**
     * Callback for opening files
     */
    private void onOpenFileClicked(Button b) {
        auto fileDialog = new FileChooserDialog("Open Log", this, FileChooserAction.OPEN);
        auto res = fileDialog.run();
        if (res == ResponseType.OK) {
            auto filename = fileDialog.getFilename();
            import logmaster.backends.file : FileBackend;
            this.addBackend(new FileBackend(filename));
        }
        fileDialog.hide();
    }

    bool receiveBackendEvents(Widget w, FrameClock f) {

        // Don't receive events if backends haven't been created
        if (this.backends.length == 0) {
            return true;
        }

        while(receiveTimeout(-1.msecs,
            (BackendEvent event) {
                LogViewer logViewer = this.logViewers[event.backendID];
                auto e = cast(BackendEvent) event;
                logViewer.handleEvent(e.payload);
            }
            // (shared BeventNewLogLines event) {
            //     auto logViewer = this.logViewers[event.backendId];
            //     // TreeIter iter = logViewer.listStore.createIter();
            //     // logViewer.listStore.setValue(iter, 0, event.line);
            // },
            // (shared BeventException event) {
            //     auto logViewer = this.logViewers[event.backendId];
            //     writeln(cast(Exception)event.e);

            //     import gtk.MessageDialog;
            //     auto dialog = new MessageDialog(this,
            //         GtkDialogFlags.DESTROY_WITH_PARENT,
            //         GtkMessageType.ERROR,
            //         GtkButtonsType.OK,
            //         format!("An Exception occured on backend thread %d (%s). A "
            //             ~ "stack trace is available in the console and the logs.")
            //             (event.backendId, backends[event.backendId].longTitle)
            //         );
            //     dialog.run();
            //     dialog.destroy();
            //     removeBackend(event.backendId);
            // }
        )) {}

        return true;
    }

    /**
     * Unregister a backend. This stops the backend thread, closes any open tabs
     * associated with it and removes it from any internal data structures.
     */
    void removeBackend(LoggingBackend backend) {
        this.removeBackend(backend.id);
    }

    /// ditto
    void removeBackend(BackendID backendId) {
        // 1. Remove from tab list
        auto backend = backends[backendId];
        backends.remove(backendId);

        // 2. Remove tab
        foreach(i; 0..notebook.getNPages()) {
            auto logviewer = cast(LogViewer)notebook.getNthPage(i);
            if (logviewer.backend.id == backendId) {
                notebook.removePage(i);
                break;
            }
        }
        logViewers.remove(backendId);

        // 3. End background process
        // backend.tid.send(BeventExitThread());
    }

    /**
     * Register a new backend. This starts the backend thread;
     */
    void addBackend(LoggingBackend backend) {
        backend.spawnIndexingThread();
        this.backends[backend.id] = backend;
        auto logViewer = new LogViewer(backend);
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
                this.window.removeBackend(this.backendId);
            }
        }


        auto label = new Label(backend.shortTitle);
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
