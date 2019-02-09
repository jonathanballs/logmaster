module logmaster.commandlauncher;

import std.process;
import std.array;
import std.parallelism;
import std.json;

import gdk.FrameClock;
import gtk.CellRendererText;
import gtk.EditableIF;
import gtk.HeaderBar;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.SearchEntry;
import gtk.Spinner;
import gtk.TreeIter;
import gtk.TreeModel;
import gtk.TreeModelFilter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Window;
import gobject.Value;
import gdk.Keysyms;
import gdk.Keymap;

class CommandLauncher : Window {
    HeaderBar headerBar;
    SearchEntry searchEntry;
    Spinner spinner;
    Task!(execute, string[])* kubectl;

    TreeView treeView;
    ListStore listStore;
    ScrolledWindow scrolledWindow;
    TreeModelFilter treeModelFilter;
    TreeIter[] iters;

    static string filterString;

    this(Window parent) {
        super("");
        /**
         * Set position
         */
        this.setTransientFor(parent);
        this.setPosition(GtkWindowPosition.CENTER_ON_PARENT);
        this.setTypeHint(GdkWindowTypeHint.DIALOG);
        this.setModal(true);
        this.setSizeRequest(600, 200);

        /**
         * Create search entry
         */
        this.searchEntry = new SearchEntry();
        this.searchEntry.setHexpand(true);
        this.searchEntry.setSizeRequest(600, -1);
        this.searchEntry.activate();
        this.searchEntry.addOnChanged((EditableIF) {
            this.filterString = searchEntry.getText();
            this.treeModelFilter.refilter();

            // Reselect the first row
            auto selection = treeView.getSelection();
            selection.selectPath(new TreePath(true));
        });

        /**
         * Create header bar
         */
        this.headerBar = new HeaderBar();
        headerBar.setProperty("spacing", 0);
        headerBar.setCustomTitle(searchEntry);
        this.setTitlebar(headerBar);

        /**
         * Add loading spinner
         */
        this.spinner = new Spinner();
        spinner.start();
        spinner.setMarginTop(15);
        spinner.setMarginBottom(15);
        this.add(spinner);

        /**
         * Fetch the list of kubernetes pods
         */
        this.kubectl = task!execute("kubectl get pods -o json".split(' '));
        this.kubectl.executeInNewThread();

        /**
         * Handle key presses
         */
        this.addOnKeyPress(&this.onKeyPress);
    }

    bool onKeyPress(GdkEventKey* g, Widget w) {

        switch(g.keyval) {
        // Open file dialog
        case Keysyms.GDK_Return:
            import std.stdio;
            TreeIter iter = this.treeView.getSelectedIter();
            writeln(treeModelFilter.getValue(iter, 0).getString());
            return true;
        default:
            return false;
        }
    }



    bool checkPid(Widget w, FrameClock f) {
        import std.stdio;
        if (this.kubectl.done) {
            // Fill in the list of pods
            string[] podNames;
            JSONValue j = parseJSON(this.kubectl.yieldForce().output);

            foreach (pod; j["items"].array) {
                podNames ~= pod["metadata"]["name"].str;
            }

            // Create the list store
            this.listStore = new ListStore([GType.STRING]);
            foreach(podName; podNames) {
                this.iters ~= listStore.createIter();
                listStore.setValue(iters[$-1], 0, podName);
            }

            // Filter
            this.treeModelFilter = new TreeModelFilter(listStore, null);
            this.treeModelFilter.setVisibleFunc(&filterTree, null, null);

            // Create the tree view
            this.treeView = new TreeView();
            treeView.setModel(treeModelFilter);
            treeView.setHeadersVisible(false);

            auto column = new TreeViewColumn(
                "Pod Name", new CellRendererText(), "text", 0);
            treeView.appendColumn(column);
            scrolledWindow = new ScrolledWindow();
            scrolledWindow.add(this.treeView);

            // Selection
            auto selection = treeView.getSelection();
            selection.selectPath(new TreePath(true));

            this.remove(this.spinner);
            this.add(scrolledWindow);
            this.showAll();

            return false;
        }
        return true;
    }

    public static extern(C) int filterTree(GtkTreeModel* m, GtkTreeIter* i, void* data) {
        TreeModel model = new TreeModel(m);
        TreeIter  iter  = new TreeIter(i);
        string name = model.getValue(iter, 0).getString();
        import std.stdio;
        import std.algorithm : canFind;
        return name.canFind(this.filterString);
    }
}