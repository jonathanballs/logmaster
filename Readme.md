# Logmaster

Logmaster is a log viewer for Linux built with GTK and D. Features include being able to read very large files (multiple gigabytes and bigger than user's memory), highlighting, searching, following, kubernetes support, unix pipe support and more.

Future developments will focus on adding log sources (attaching to processes, journalctl etc), improved highlighting and parsing, increasing performance, measuring and plotting log velocity and more. Contributions are welcome!

Logmaster is still alpha software and may be buggy and unoptimised in certain places. Please create an issue if you find a bug or can think of an improvement.

![Screenshot](/screenshot.png)

## Compiling
You will need the D build tools to compile logmaster. Navigate to the root directory and run `dub build`.

## Installing
Packages for Arch and Ubuntu coming soon...

## Command line usage
Open a file: `logmaster file.log`

Log from stdin: `npm start | logmaster -`
