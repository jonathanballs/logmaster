module logmaster.ui.logviewer;

import std.concurrency;
import std.format;
import std.stdio;
import std.variant;
import core.thread;

import cairo.Context;
import gdk.FrameClock;
import gdk.Rectangle;
import gtk.Adjustment;
import gtk.Alignment;
import gtk.Box;
import gtk.CellRendererText;
import gtk.CellRendererText;
import gtk.CssProvider;
import gtk.Layout;
import gtk.ProgressBar;
import gtk.Revealer;
import gtk.ScrolledWindow;
import gtk.SearchBar;
import gtk.SearchEntry;
import gtk.Statusbar;
import gtk.StyleContext;
import gtk.Toolbar;
import gtk.TreeIter;
import gtk.TreeViewColumn;
import gtk.Widget;
import gobject.Value;

import logmaster.backends;
import logmaster.backendevents;
import logmaster.backends.filters.regex;

class LogViewer : Box {
    // Meta
    LoggingBackend backend;
    BackendRegexFilter filter;

    // Loading progress. Log Viewer will show either a loading progress or
    // another box with searchbar/scrolled window/status bar
    Alignment progressAlignment;
    ProgressBar progressBar;

    // Log view
    SearchBar searchBar;
    SearchEntry searchEntry;
    ScrolledWindow scrolledWindow;
    Layout layout;
    Statusbar statusBar;
    private enum rowHeight = 20;


    this(LoggingBackend backend) {
        super(GtkOrientation.VERTICAL, 20);
        this.backend = backend;
        this.backend.onNewLines.connect(() {
            this.queueDraw();
        });
        this.setSpacing(0);

        /**
         * Draw a progress bar
         */
        this.progressBar = new ProgressBar();
        progressBar.setHalign(GtkAlign.CENTER);
        progressBar.setValign(GtkAlign.CENTER);
        progressBar.setFraction(this.backend.indexingPercentage);

        /**
         * Create the search bar
         */
        searchBar = new SearchBar();
        searchEntry = new SearchEntry();
        searchBar.add(searchEntry);
        searchBar.connectEntry(searchEntry);
        searchEntry.setSizeRequest(500, -1);
        searchEntry.setHexpand(true);

        /**
         * Create the layout
         */
        this.layout = new Layout(null, null);
        layout.setSize(100, rowHeight * cast(uint) this.backend.lines.length);
        layout.addOnDraw(&this.onDraw);
        this.scrolledWindow = new ScrolledWindow();
        scrolledWindow.add(layout);

        /**
         * Create the statusbar and remove margins and set its colour.
         */
        statusBar = new Statusbar();
        statusBar.setMarginTop(0);
        statusBar.setMarginBottom(0);
        statusBar.setMarginLeft(0);
        statusBar.setMarginRight(0);
        StyleContext styleContext = statusBar.getStyleContext();
        CssProvider cssProvider = new CssProvider();
        cssProvider.loadFromData("statusbar {"
            ~ "border-top-width: 1px;"
            ~ "border-top-style: solid;"
            ~ "border-color: #1b1b1b;"
            ~ "background-color: @theme_bg_color }");
        styleContext.addProvider(cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);


        if (this.backend.indexingPercentage < 1.0) {
            this.packStart(progressBar, true, true, 0);
        } else {
            this.packStart(searchBar, false, true, 0);
            this.packStart(scrolledWindow, true, true, 0);
            this.packStart(statusBar, false, true, 0);
        }

        /**
         * Connect to backend indexing progress
         */
        this.backend.onIndexingProgress.connect((float p) {
            if (p < 1.0) {
                if (progressBar) progressBar.setFraction(p);
            } else if (this.progressBar) {
                this.remove(progressBar);
                this.progressBar = null;
                this.packStart(searchBar, false, true, 0);
                this.packStart(scrolledWindow, true, true, 0);
                this.packStart(statusBar, false, true, 0);
                this.showAll();
            }
        });
    }

    /**
     * Toggles whether the search bar is visible or not
     */
    void toggleSearchBar() {
        searchBar.setSearchMode(!searchBar.getSearchMode());
    }

    /**
     * Callback for layout drawing
     */
    bool onDraw(Scoped!Context c, Widget w) {
        LogLines lines = filter ? filter.lines : backend.lines;
        statusBar.push(statusBar.getContextId("description"), format!"%,d Lines"(lines.length));
        if (!lines.length) return true;
        drawLogLines(&c, cast(Layout) w, lines);
        return true;
    }

    /**
     * Draw a set of log lines onto a layout. This is where the actual logs are
     * rendered onto the screen.
     * Params:
     *      c = The Cairo `Context` used for drawing
     *      layout = The `GtkLayout` to render to
     *      lines = Logmaster `LogLines` which need to be rendered
     */
    private bool drawLogLines(Scoped!Context* c, Layout layout, LogLines lines) {
        Adjustment vAdjustment = layout.getVadjustment();
        uint firstLineNumber = cast(uint) vAdjustment.getValue() / rowHeight;
        uint firstLineY = firstLineNumber * rowHeight - cast(uint) vAdjustment.getValue();

        // TODO: Calculate this with pango
        auto charWidth = 9;
        layout.setSize(cast (uint) lines.longestLineLength * charWidth,
            rowHeight * cast(uint) lines.length);

        GdkRectangle viewportSize;
        layout.getAllocation(viewportSize);

        auto x = -cast(uint) layout.getHadjustment().getValue();
        foreach (i; 0..(viewportSize.height / rowHeight) + 2) {
            if (firstLineNumber + i > lines.length-1) break;

            string message = lines[firstLineNumber + i].message;
            uint y = firstLineY + i*rowHeight;
            GdkRectangle rect = GdkRectangle(x, y,
                cast(uint) lines.longestLineLength*charWidth, this.rowHeight);
            CellRendererText renderer = new CellRendererText();
            renderer.setProperty("text", message);
            renderer.setProperty("family", "Monospace");
            renderer.render(*c, layout, &rect, &rect, GtkCellRendererState.INSENSITIVE);
        }

        return true;
    }
}
