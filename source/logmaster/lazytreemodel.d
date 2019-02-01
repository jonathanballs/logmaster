module logmaster.lazytreemodel;

import std.typecons;

import glib.RandG;
import gobject.ObjectG;
import gobject.Value;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeModelIF;
import gtk.TreeModelT;
import gtkd.Implement;

alias Column = Tuple!(string, "title", GType, "type");

struct CustomRecord
{
  /* data - you can extend this */
  string name;
  uint yearBorn;

  /* admin stuff used by the custom list model */
  uint lineID;   /* Id of this line */
}

enum CustomListColumn
{
    Record = 0,
    Name,
    YearBorn,
    NColumns,
}

class LazyTreeModel : ObjectG, TreeModelIF
{
    Column[] columns;
    CustomRecord*[] rows;
    int stamp;

    mixin ImplementInterface!(GObject, GtkTreeModelIface);
    mixin TreeModelT!(GtkTreeModel);

    public this()
    {
        super(getType(), null);

        columns = [
            Column("lineID", GType.UINT),
            Column("name", GType.STRING),
            Column("Year Born", GType.UINT)];

        stamp = RandG.randomInt();

        foreach (i; 0..200) {
            this.appendRecord("Jonathan Balls", 1996);
        }
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
     * simply store a pointer to our CustomRecord structure that represents that
     * row in the tree iter.
     */
    override int getIter(TreeIter iter, TreePath path)
    {
        CustomRecord* record;
        int[]         indices;
        int           n, depth;

        indices = path.getIndices();
        depth   = path.getDepth();

        /* we do not allow children */
        if (depth != 1)
            return false;//throw new Exception("We only except lists");

        n = indices[0]; /* the n-th top level row */

        if ( n >= rows.length || n < 0 )
            return false;

        record = rows[n];

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
        CustomRecord* record;
      
        if ( iter is null || iter.userData is null || iter.stamp != stamp )
            return null;

        record = rows[iter.getUserData!(uint)];

        path = new TreePath(record.lineID);

        return path;
    }


    /*
     * Returns a row's exported data columns (_get_value is what
     * gtk_tree_model_get uses)
     */

    override Value getValue(TreeIter iter, int column, Value value = null)
    {
        CustomRecord  *record;

        if ( value is null )
            value = new Value();

        if ( iter is null || column >= columns.length || iter.stamp != stamp )
            return null;

        value.init(columns[column].type);

        record = rows[iter.getUserData!(uint)];

        if ( record is null || record.lineID >= rows.length )
            return null;

        import std.stdio;

        switch(column)
        {
            case CustomListColumn.Record:
                value.setPointer(record);
                break;

            case CustomListColumn.Name:
                value.setString(record.name);
                break;

            case CustomListColumn.YearBorn:
                value.setUint(record.yearBorn + record.lineID);
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
        CustomRecord* record, nextrecord;
      
        if ( iter is null || iter.userData is null || iter.stamp != stamp )
            return false;

        record = rows[iter.getUserData!(uint)];

        /* Is this the last record in the list? */
        if ( (record.lineID + 1) >= rows.length )
            return false;

        nextrecord = rows[(record.lineID + 1)];

        if ( nextrecord is null || nextrecord.lineID != record.lineID + 1 )
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
        if ( rows.length == 0 )
            return false;

        /* Set iter to first item in list */
        iter = new TreeIter();
        iter.stamp     = stamp;
        iter.setUserData(rows[0].lineID);

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
            return cast(int) rows.length;

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
        CustomRecord  *record;

        /* a list has only top-level rows */
        if( parent !is null )
            return false;

        if( n >= rows.length )
            return false;

        record = rows[n];

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

    /*
     * Empty lists are boring. This function can be used in your own code to add
     * rows to the list. Note how we emit the "row-inserted" signal after we
     * have appended the row internally, so the tree view and other interested
     * objects know about the new row.
     */
    void appendRecord(string name, uint yearBorn)
    {
        TreeIter      iter;
        TreePath      path;
        CustomRecord* newrecord;
        uint          lineID;

        newrecord = new CustomRecord;

        newrecord.name = name;
        newrecord.yearBorn = yearBorn;
        newrecord.lineID = cast(uint) rows.length;

        rows ~= newrecord;

        /* inform the tree view and other interested objects (e.g. tree row
         *  references) that we have inserted a new row, and where it was
         *  inserted */

        path = new TreePath(newrecord.lineID);

        iter = new TreeIter();
        getIter(iter, path);

        rowInserted(path, iter);
    }
}
