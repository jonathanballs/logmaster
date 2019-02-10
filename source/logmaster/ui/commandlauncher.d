module logmaster.ui.commandlauncher;

import std.process;
import std.array;
import std.parallelism;
import std.json;
import std.stdio;

import gdk.FrameClock;
import gtk.CellRendererText;
import gtk.Dialog;
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
import gtk.TreeSelection;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Window;
import gobject.Value;
import gdk.Keysyms;
import gdk.Keymap;

alias callback_t = void delegate(string);

class CommandLauncher : Dialog {
    HeaderBar headerBar;
    SearchEntry searchEntry;
    Spinner spinner;
    Task!(execute, string[])* kubectl;

    TreeView treeView;
    ListStore listStore;
    ScrolledWindow scrolledWindow;
    TreeModelFilter treeModelFilter;
    TreeIter[] iters;

    callback_t callback;

    Window parent;
    string filterString;

    bool destroyed = false;

    this(Window parent, callback_t dlg) {
        super();
        this.addOnDestroy((Widget w) {
            this.destroyed = true;
        });

        this.parent = parent;
        this.callback = dlg;

        /**
         * Set position
         */
        this.setTransientFor(parent);
        this.setPosition(GtkWindowPosition.CENTER_ON_PARENT);
        this.setTypeHint(GdkWindowTypeHint.DIALOG);
        this.setModal(true);
        this.setSizeRequest(600, 300);

        /**
         * Create search entry
         */
        this.searchEntry = new SearchEntry();
        this.searchEntry.setHexpand(true);
        this.searchEntry.setSizeRequest(600, -1);
        this.searchEntry.activate();
        this.searchEntry.addOnChanged((EditableIF) {
            if (!this.treeModelFilter) return;
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
        this.getContentArea().add(spinner);

        /**
         * Fetch the list of kubernetes pods
         */
        this.kubectl = task!execute("kubectl get pods -o json".split(' '));
        this.kubectl.executeInNewThread();

        /**
         * Handle key presses
         */
        this.addTickCallback(&this.checkPid);
        this.addOnKeyPress(&this.onKeyPress);
        this.showAll();
    }

    bool onKeyPress(GdkEventKey* g, Widget w) {
        switch(g.keyval) {
        // Open file dialog
        case Keysyms.GDK_Return:
            TreeIter iter = this.treeView.getSelectedIter();
            if (iter) {
                callback(treeModelFilter.getValue(iter, 0).getString());
            }
            return true;
        case Keysyms.GDK_Escape:
            this.destroy();
            return true;
        default:
            return false;
        }
    }



    bool checkPid(Widget w, FrameClock f) {
        if (destroyed) return false;

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
            this.treeModelFilter.setVisibleFunc(&filterTree, &this.filterString, null);

            // Create the tree view
            this.treeView = new TreeView();
            treeView.setModel(treeModelFilter);
            treeView.setHeadersVisible(false);
            this.treeView.getSelection.addOnChanged((TreeSelection s) {
                this.treeView.scrollToCell(new TreePath(true), null, true, 0, 0);
            });

            auto column = new TreeViewColumn(
                "Pod Name", new CellRendererText(), "text", 0);
            treeView.appendColumn(column);
            scrolledWindow = new ScrolledWindow();
            scrolledWindow.setVexpand(true);
            scrolledWindow.add(this.treeView);

            // Selection
            auto selection = treeView.getSelection();
            selection.selectPath(new TreePath(true));

            this.getContentArea().remove(this.spinner);
            this.getContentArea().add(scrolledWindow);
            this.getContentArea().showAll();

            return false;
        }
        return true;
    }

    public static extern(C) int filterTree(GtkTreeModel* m, GtkTreeIter* i, void* data) {
        TreeModel model = new TreeModel(m);
        TreeIter  iter  = new TreeIter(i);
        string name = model.getValue(iter, 0).getString();
        import std.algorithm : canFind;
        return name.canFind(*cast(string*) data);
    }
}