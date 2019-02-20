module logmaster.ui.colors;

import std.algorithm;
import std.array;
import std.typecons;
import std.regex;
import gdk.Color;
import std.stdio;

// Semantic color names
enum HighlightType {
    None,
    Timestamp,
    Number,
    String
}

auto dateRE = ctRegex!("[0-9]+\\-[0-9]+\\-[0-9]+ [0-9]+:[0-9]+");
auto numberRE = ctRegex!("[0-9\\.]+");

alias ColoredString = Tuple!(string, "message", HighlightType, "type");
alias ColorScheme = Color[HighlightType];

ColoredString[] highlightString(string s) {
    auto r = highlightString(s, dateRE, HighlightType.Timestamp);
    ColoredString[] r2;
    foreach(hs; r) {
        if (hs.type == HighlightType.None) {
            r2 ~= highlightString(hs.message, numberRE, HighlightType.Number);
        } else {
            r2 ~= hs;
        }
    }

    return r2;
}

private ColoredString[] highlightString(string s, Regex!char re, HighlightType t) {
    ColoredString[] r;
    ulong offset;
    foreach(m; s.matchAll(re)) {
        if (m.pre[offset..$].length)
            r ~= ColoredString(m.pre[offset..$], HighlightType.None);
        r ~= ColoredString(m.hit, t);
        offset = m.pre.length + m.hit.length;
    }
    if (s[offset..$].length)
        r ~= ColoredString(s[offset..$], HighlightType.None);
    return r;
}

unittest {
    import std.stdio;
    auto r = highlightString("2018-02-23 12:21 ayylmaoo 3.2.4");
    foreach(s; r) {
        writeln(s);
    }
}
