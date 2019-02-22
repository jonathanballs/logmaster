module logmaster.resources;

import std.file;
import std.path;
import std.array;
import std.stdio;

string getResourcePath(string resourceName) {
    // If installed then get from /usr/local/share/
    if (dirName(thisExePath()) == "/usr/bin") {
        return chainPath("/usr/local/share/logmaster/", resourceName).array;
    } else {
        return chainPath(dirName(thisExePath()), "resources/", resourceName).array;
    }
}
