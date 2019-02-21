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

auto dateRE = regex([
    "[0-9]+\\-[0-9]+\\-[0-9]+ [0-9]+:[0-9]+",
    "(-?(?:[1-9][0-9]*)?[0-9]{4})-(1[0-2]|0[1-9])-(3[01]|0[1-9]|[12][0-9])"
        ~ "T(2[0-3]|[01][0-9]):([0-5][0-9]):([0-5][0-9])(\\.[0-9]+)?(Z)",
    "([\\w:/]+\\s[+\\-]\\d{4})"
]);

auto numberRE = ctRegex!("[0-9]+[0-9.]*");

alias HighlightedString = Tuple!(string, "message", HighlightType, "type");
alias ColoredString = Tuple!(string, "message", Color, "color");
alias ColorScheme = Color[HighlightType];

ColorScheme afterglow;
static this() {
    afterglow = [
        HighlightType.None: new Color(214, 214, 214),
        HighlightType.Number: new Color(180, 201, 115),
        HighlightType.Timestamp: new Color(108, 153, 187),
    ];
}

private HighlightedString[] highlightString(string s) {
    auto r = highlightString(s, dateRE, HighlightType.Timestamp);
    HighlightedString[] r2;
    foreach(hs; r) {
        if (hs.type == HighlightType.None) {
            r2 ~= highlightString(hs.message, numberRE, HighlightType.Number);
        } else {
            r2 ~= hs;
        }
    }

    return r2;
}

private HighlightedString[] highlightString(string s, Regex!char re, HighlightType t) {
    HighlightedString[] r;
    ulong offset;
    foreach(m; s.matchAll(re)) {
        if (m.pre[offset..$].length)
            r ~= HighlightedString(m.pre[offset..$], HighlightType.None);
        r ~= HighlightedString(m.hit, t);
        offset = m.pre.length + m.hit.length;
    }
    if (s[offset..$].length)
        r ~= HighlightedString(s[offset..$], HighlightType.None);
    return r;
}

ColoredString[] colorString(string s) {
    auto highlighted = highlightString(s);
    ColoredString[] r;
    foreach(h; highlighted) {
        r ~= ColoredString(h.message, afterglow[h.type]);
    }
    return r;
}

unittest {
    import std.stdio;
    auto r = highlightString("2018-02-23 12:21 ayylmaoo 3.2.4");
    foreach(s; r) {
        writeln(s);
    }
}
