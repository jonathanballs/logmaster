module logmaster.lazytreemodel;

import std.typecons;
import std.stdio;

import glib.RandG;
import gobject.ObjectG;
import gobject.Value;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeModelIF;
import gtk.TreeModelT;
import gtkd.Implement;
import gtk.TreeViewColumn;
import gtk.CellRendererText;

import logmaster.backend;

alias Column = Tuple!(string, "title", GType, "type");

class LazyTreeModel : ObjectG, TreeModelIF
{
    Column[] columns;
    int stamp;
    LoggingBackend backend;

    mixin ImplementInterface!(GObject, GtkTreeModelIface);
    mixin TreeModelT!(GtkTreeModel);

    public this(LoggingBackend backend) {
        super(getType(), null);

        this.backend = backend;

        columns = [
            Column("lineID", GType.ULONG),
            Column("message", GType.STRING)];

        stamp = RandG.randomInt();
    }

    TreeViewColumn[] getTreeViewColumns() {
        TreeViewColumn[] ret;
        foreach (i, column; this.columns) {
            if (i==0) continue;

            auto treeViewColumn = new TreeViewColumn();
            auto renderer = new CellRendererText();
            treeViewColumn.packStart(renderer, true);
            treeViewColumn.addAttribute(renderer, "text", cast(int)i);
            treeViewColumn.setSizing(GtkTreeViewColumnSizing.FIXED);
            treeViewColumn.setTitle(this.columns[i].title);
            ret ~= treeViewColumn;
        }

        return ret;
    }

    /*
     * tells the rest of the world whether our tree model has any special
     * characteristics. In our case, we have a list model (instead of a tree),
     * and each tree iter is valid as long as the row in question exists, as it
     * only contains a pointer to our struct.
     */
    override GtkTreeModelFlags getFlags()
    {
        return (GtkTreeModelFlags.LIST_ONLY);
    }


    /*
     * tells the rest of the world how many data columns we export via the tree
     * model interface
     */

    override int getNColumns()
    {
        return cast(int) columns.length;
    }

    /*
     * tells the rest of the world which type of data an exported model column
     * contains
     */
    override GType getColumnType(int index)
    {
        if ( index >= columns.length || index < 0 )
            return GType.INVALID;

        return columns[index].type;
    }

    /*
     * converts a tree path (physical position) into a tree iter structure (the
     * content of the iter fields will only be used internally by our model). We
     * simply store a pointer to our LogLine structure that represents that
     * row in the tree iter.
     */
    override int getIter(TreeIter iter, TreePath path)
    {
        auto indices = path.getIndices();
        auto depth   = path.getDepth();


        /* we do not allow children */
        if (depth != 1)
            return false;//throw new Exception("We only except lists");

        auto n = indices[0]; /* the n-th top level row */

        import std.stdio;
        if ( n >= backend.opDollar() || n < 0 )
            return false;

        auto record = backend[n];

        /* We simply store a pointer to our custom record in the iter */
        iter.stamp     = stamp;
        iter.setUserData(record.lineID);

        return true;
    }


    /*
     * converts a tree iter into a tree path (ie. the physical position of that
     * row in the list).
     */
    override TreePath getPath(TreeIter iter)
    {
        TreePath path;
        LogLine record;
      
        if ( iter is null || iter.userData is null || iter.stamp != stamp )
            return null;

        record = backend[iter.getUserData!(ulong)];

        path = new TreePath(cast(uint) record.lineID);

        return path;
    }


    /*
     * Returns a row's exported data columns (_get_value is what
     * gtk_tree_model_get uses)
     */

    override Value getValue(TreeIter iter, int column, Value value = null)
    {
        LogLine  record;

        if ( value is null )
            value = new Value();

        if ( iter is null || column >= columns.length || iter.stamp != stamp )
            return null;

        value.init(columns[column].type);

        record = backend[iter.getUserData!(ulong)];

        if ( record.lineID >= backend.opDollar() )
            return null;

        switch(column)
        {
            case 1:
                value.setString(record.message);
                break;

            case 2:
                value.setUlong(cast(ulong) record.lineID);
                break;

            default:
                break;
        }

        return value;
    }


    /*
     * Takes an iter structure and sets it to point to the next row.
     */
    override bool iterNext(TreeIter iter)
    {
        LogLine record, nextrecord;
      
        if ( iter is null || iter.userData is null || iter.stamp != stamp )
            return false;
        
        // writeln(iter.getUserData!ulong);

        record = backend[iter.getUserData!(ulong)];
        writeln(record.lineID);

        /* Is this the last record in the list? */
        if ( (record.lineID + 1) >= backend.opDollar() )
            return false;

        nextrecord = backend[(record.lineID + 1)];

        if ( nextrecord.lineID != record.lineID + 1 )
            throw new Exception("Invalid next record");

        iter.stamp     = stamp;
        iter.setUserData(nextrecord.lineID);

        return true;
    }


    /*
     * Returns TRUE or FALSE depending on whether the row specified by 'parent'
     * has any children. If it has children, then 'iter' is set to point to the
     * first child. Special case: if 'parent' is NULL, then the first top-level
     * row should be returned if it exists.
     */

    override bool iterChildren(out TreeIter iter, TreeIter parent)
    {
        /* this is a list, nodes have no children */
        if ( parent !is null )
            return false;

        /* No rows => no first row */
        if ( backend.opDollar() == 0 )
            return false;

        /* Set iter to first item in list */
        iter = new TreeIter();
        iter.stamp     = stamp;
        iter.setUserData(backend[0].lineID);

        return true;
    }


    /*
     * Returns TRUE or FALSE depending on whether the row specified by 'iter'
     * has any children. We only have a list and thus no children.
     */
    override bool iterHasChild(TreeIter iter)
    {
        return false;
    }


    /*
     * Returns the number of children the row specified by 'iter' has. This is
     * usually 0, as we only have a list and thus do not have any children to
     * any rows. A special case is when 'iter' is NULL, in which case we need to
     * return the number of top-level nodes, ie. the number of rows in our list.
     */
    override int iterNChildren(TreeIter iter)
    {
        /* special case: if iter == NULL, return number of top-level rows */
        if ( iter is null )
            return cast(int) backend.opDollar();

        return 0; /* otherwise, this is easy again for a list */
    }


    /*
     * If the row specified by 'parent' has any children, set 'iter' to the n-th
     * child and return TRUE if it exists, otherwise FALSE. A special case is
     * when 'parent' is NULL, in which case we need to set 'iter' to the n-th
     * row if it exists.
     */
    override bool iterNthChild(out TreeIter iter, TreeIter parent, int n)
    {
        LogLine  record;

        /* a list has only top-level rows */
        if( parent !is null )
            return false;

        if( n >= backend.opDollar() )
            return false;

        record = backend[n];

        iter = new TreeIter();
        iter.stamp     = stamp;
        iter.setUserData(record.lineID);

        return true;
    }


    /*
     * Point 'iter' to the parent node of 'child'. As we have a list and thus no
     * children and no parents of children, we can just return FALSE.
     */
    override bool iterParent(out TreeIter iter, TreeIter child)
    {
        return false;
    }
}
