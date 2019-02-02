module logmaster.backends.example;import std.algorithm;
import std.concurrency;
import std.conv;
import std.stdio;
import std.file;
import std.format;
import std.string;
import std.variant;
import core.time;

import logmaster.backend;
// import file;
// import kubernetes;

// int exampleMain(string[] args) {
//     auto filename = args.length > 1 ? args[1] : "/var/log/pacman.log";

//     auto k = new KubernetesLogs("neo4j-store-64d9c76b49-xg84t");
//     runBenchmark(k);

//     auto fbackend = new FileLog("/home/jonathan/biglog.json");
//     fbackend.spawnIndexingThread();

//     while (true) {
//         try {
//             write(">>> ");
//             string[] command = readln().chomp().split(' ');
//             if (!command.length) {
//                 continue;
//             }

//             if (command[0] == "p") {
//                 writeln (fbackend.indexingPercentage);
//             }

//             // return line numbers
//             if (command[0][0] == 'l') {
//                 long lineNumber = 1;
//                 if (command.length > 1) {
//                     lineNumber = command[1].to!long;
//                 }
//                 writeln(fbackend[lineNumber]);
//             }
//         } catch (Exception e) {
//             writeln(e);
//             continue;
//         }
//     }
// }

// void runBenchmark(RawLogI log) {
//     import std.datetime.stopwatch : StopWatch;
//     StopWatch s;
//     s.start();

//     log.createLineIndex();
//     writeln(log.lines[0]);
//     s.stop();
//     float fsizeGb = log.size() / 1000000000.0;
//     float secs = s.peek.total!"msecs" / 1000.0;
//     writeln(format!"Read %.2fGb in %.2fs (%.2fGb/s)"(
//                 fsizeGb, secs, fsizeGb / secs));

//     writeln("Testing iteration...");
//     s = StopWatch();
//     s.start();
//     ulong totalLength;
//     ulong numLines;
//     foreach (l; log.lines[0..$-1]) {
//         totalLength += l.length;
//         numLines++;
//     }
//     s.stop();
//     secs = s.peek.total!"msecs" / 1000.0;
//     writeln(format!"Iterated %.2fGb (%d lines) in %.2fs (%.2fGb/s)"(
//                 fsizeGb, numLines, secs, fsizeGb / secs));

//     return;
// }
