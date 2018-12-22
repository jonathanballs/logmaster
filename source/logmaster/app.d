import std.stdio;

import logmaster.unixStreamBackend;

void main(string[] args)
{
    writeln("Logmaster logging library");
    auto l = new UnixStreamBackend(stdin);
    l.readLines();
}

// unbuffer npm start | logmaster -
// logmaster -- npm start
// logmaster file.txt
// logmaster /var/log/mongodb/mongod.log
// logmaster --docker ab4a
