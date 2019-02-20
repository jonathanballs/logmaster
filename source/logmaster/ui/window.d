module logmaster.ui.window;

import std.concurrency;
import std.stdio;
import core.time;

import gtk.Button;
import gtk.CellRendererText;
import gtk.HeaderBar;
import gtk.FileChooserDialog;
import gtk.Image;
import gtk.Label;
import gtk.Box;
import gtk.MainWindow;
import gtk.Notebook;
import gtk.Widget;
import gdk.FrameClock;
import gdk.Keysyms;
import gdk.Pixbuf;
import glib.Timeout;

import logmaster.constants;
import logmaster.backends;
import logmaster.backendevents;
import logmaster.filters;
import logmaster.ui.logviewer;
import logmaster.ui.commandlauncher;


/// GtkMainWindow subclass for Logmaster
class LogmasterWindow : MainWindow {
    LoggingBackend[BackendID] backends;
    RegexFilter[FilterID] filters;

    LogViewer[BackendID] logViewers;

    Notebook notebook;
    HeaderBar headerBar;
    CommandLauncher commandLauncher;

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

        // Kubernetes button
        auto icon = new Image();
        icon.setFromIconName("folder-documents-symbolic", GtkIconSize.MENU);
        auto kubeIcon = new Pixbuf("source/logmaster/icons/kubernetes.svg", 18, 18);
        icon.setFromPixbuf(kubeIcon);
        Button kubernetesButton = new Button();
        kubernetesButton.setImage(icon);
        kubernetesButton.addOnClicked((Button b) {
            if (this.commandLauncher) return;
            this.commandLauncher = new CommandLauncher(this, (string podName) {
                this.commandLauncher.destroy();
                import logmaster.backends.subprocess;
                auto backend = new SubprocessBackend(
                    ["kubectl", "logs", "-f", podName], podName);
                this.addBackend(backend);
            });
            this.addTickCallback(&commandLauncher.checkPid);
            this.commandLauncher.addOnDestroy((Widget w) {
                this.commandLauncher = null;
            });
        });
        headerBar.packStart(kubernetesButton);

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
        auto currentLogViewer = cast(LogViewer) notebook.getNthPage(notebook.getCurrentPage);

        if (currentLogViewer.searchBar.getSearchMode()) {
            import gdk.Event : Event;
            GdkEvent* e = cast(GdkEvent*) g;
            auto event = new Event(e);

            if (g.keyval == Keysyms.GDK_Return) {
                string searchString = currentLogViewer.searchEntry.getText();
                if (searchString) {
                    auto filter = new RegexFilter(currentLogViewer.backend, searchString);
                    currentLogViewer.backend.setFilter(filter);
                } else {
                    currentLogViewer.backend.setFilter(null);
                }
                currentLogViewer.queueDraw();
            }

            if (g.state & ModifierType.CONTROL_MASK && g.keyval == Keysyms.GDK_f)
                currentLogViewer.toggleSearchBar();

            return currentLogViewer.searchEntry.handleEvent(event);
        }

        // If CTRL key pressed
        if (g.state & ModifierType.CONTROL_MASK) {
            switch(g.keyval) {
            case Keysyms.GDK_f:
                currentLogViewer.toggleSearchBar();
                break;
            // Open file dialog
            case Keysyms.GDK_o:
                this.onOpenFileClicked(new Button());
                break;
            // Close current tab/window
            case Keysyms.GDK_w:
                if (notebook.getNPages() == 0) {
                    this.destroy();
                    break;
                } else {
                    this.removeBackend(currentLogViewer.backend.id);
                }
                break;
            // Quit the program
            case Keysyms.GDK_q:
                this.destroy();
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
            case Keysyms.GDK_k:
                if (this.commandLauncher) break;
                this.commandLauncher = new CommandLauncher(this, (string podName) {
                    this.commandLauncher.destroy();
                    import logmaster.backends.subprocess;
                    auto backend = new SubprocessBackend(
                        ["kubectl", "logs", "-f", podName], podName);
                    this.addBackend(backend);
                });
                this.addTickCallback(&commandLauncher.checkPid);
                this.commandLauncher.addOnDestroy((Widget w) {
                    this.commandLauncher = null;
                });
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

        // Receive events for up to 50ms
        auto startTime = MonoTime.currTime;
        while((MonoTime.currTime - startTime) < 50.msecs && receiveTimeout(-1.msecs,
            (BackendEvent event) {
                if (event.backendID !in logViewers) {
                    writeln("ERR: Recieved event for backend that doesn't exist");
                    return;
                }
                auto backend = this.backends[event.backendID];
                backend.handleEvent((cast(BackendEvent) event).payload);
            }
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
        auto button = new CloseButton(backend.id, this);
        button.setRelief(GtkReliefStyle.NONE);
        button.setImage(new Image(StockID.CLOSE, GtkIconSize.MENU));

        auto icon = new Image();
        icon.setFromIconName("folder-documents-symbolic", GtkIconSize.MENU);

        try {
            import logmaster.backends.subprocess;
            if (typeid(backend) == typeid(SubprocessBackend)) {
                import gdk.Pixbuf;
                auto kubeIcon = new Pixbuf("source/logmaster/icons/kubernetes.svg", 18, 18);
                icon.setFromPixbuf(kubeIcon);
            }
        } catch (Exception e) {
            writeln("Failed to load icon ", e);
        }

        icon.setMarginRight(8);

        label.setHexpand(true);
        label.setEllipsize(PangoEllipsizeMode.END);
        auto box = new Box(GtkOrientation.HORIZONTAL, 0);


        box.packStart(icon, false, false, 0);
        box.packStart(label, true, true, 0);
        box.packEnd(button, false, true, 0);
        box.setSizeRequest(180, -1);
        box.showAll();

        auto pageNum = this.notebook.appendPage(logViewer, box);
        this.showAll();
        this.notebook.setCurrentPage(pageNum);
        this.notebook.show();
    }
}
