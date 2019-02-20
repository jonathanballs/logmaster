module logmaster.resources;

import std.file;
import std.path;
import std.array;
import std.stdio;

string getResourcePath(string resourceName) {
    return chainPath(dirName(thisExePath()), "resources/", resourceName).array;
}
