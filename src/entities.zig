//! HTML 4 character-reference decoding for Graphviz-compatible plain labels.
//!
//! The named-entity table is generated from Graphviz's
//! `lib/common/entities.html`, which is itself a copy of the W3C HTML 4 table.
//! It is embedded here so parsing labels never depends on Graphviz at runtime.

const std = @import("std");

const max_entity_name_len = 8;

const Entity = struct {
    name: []const u8,
    codepoint: u21,
};

const ParsedReference = struct {
    codepoint: u21,
    /// Number of bytes consumed after `&`, including the terminating `;`.
    consumed: usize,
};

/// Decodes semicolon-terminated HTML 4 named and numeric character references.
///
/// Unknown names, malformed numeric values, missing semicolons, surrogate
/// values, and out-of-range Unicode values are preserved byte-for-byte. The
/// replacement is deliberately a single pass: `&#38;alpha;` becomes
/// `&alpha;`, not `α`, matching Graphviz's plain-label processing.
pub fn decodeAlloc(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    if (std.mem.indexOfScalar(u8, value, '&') == null) return allocator.dupe(u8, value);

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var literal_start: usize = 0;
    var cursor: usize = 0;
    while (cursor < value.len) {
        if (value[cursor] != '&') {
            cursor += 1;
            continue;
        }

        const reference = parseReference(value[cursor + 1 ..]) orelse {
            cursor += 1;
            continue;
        };
        try out.appendSlice(allocator, value[literal_start..cursor]);

        var encoded: [4]u8 = undefined;
        const encoded_len = try std.unicode.utf8Encode(reference.codepoint, &encoded);
        try out.appendSlice(allocator, encoded[0..encoded_len]);

        cursor += 1 + reference.consumed;
        literal_start = cursor;
    }
    try out.appendSlice(allocator, value[literal_start..]);
    return out.toOwnedSlice(allocator);
}

fn parseReference(value: []const u8) ?ParsedReference {
    if (value.len == 0) return null;
    if (value[0] == '#') return parseNumericReference(value);

    // HTML 4 entity names are no longer than eight bytes. Bounding the scan
    // also prevents an arbitrary later semicolon from turning a long unknown
    // sequence into a candidate lookup.
    const scan_len = @min(value.len, max_entity_name_len + 1);
    const semicolon = std.mem.indexOfScalar(u8, value[0..scan_len], ';') orelse return null;
    if (semicolon == 0 or semicolon > max_entity_name_len) return null;
    const codepoint = lookupNamed(value[0..semicolon]) orelse return null;
    return .{ .codepoint = codepoint, .consumed = semicolon + 1 };
}

fn parseNumericReference(value: []const u8) ?ParsedReference {
    var digits_start: usize = 1;
    var base: u8 = 10;
    if (digits_start < value.len and (value[digits_start] == 'x' or value[digits_start] == 'X')) {
        base = 16;
        digits_start += 1;
    }
    if (digits_start >= value.len) return null;

    // Any Unicode scalar fits in seven decimal or six hexadecimal digits.
    // Bound the search so malformed `&#...` input remains linear-time even
    // when it contains many ampersands and no terminating semicolon.
    const max_digits: usize = if (base == 16) 6 else 7;
    const scan_len = @min(value.len - digits_start, max_digits + 1);
    const relative_semicolon = std.mem.indexOfScalar(u8, value[digits_start..][0..scan_len], ';') orelse return null;
    if (relative_semicolon == 0) return null;
    const semicolon = digits_start + relative_semicolon;
    const codepoint = std.fmt.parseInt(u21, value[digits_start..semicolon], base) catch return null;
    if (!isUnicodeScalar(codepoint)) return null;
    return .{ .codepoint = codepoint, .consumed = semicolon + 1 };
}

fn isUnicodeScalar(codepoint: u21) bool {
    return codepoint != 0 and
        codepoint <= 0x10ffff and
        !(codepoint >= 0xd800 and codepoint <= 0xdfff);
}

fn lookupNamed(name: []const u8) ?u21 {
    var low: usize = 0;
    var high: usize = html4_entities.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        switch (std.mem.order(u8, name, html4_entities[mid].name)) {
            .lt => high = mid,
            .eq => return html4_entities[mid].codepoint,
            .gt => low = mid + 1,
        }
    }
    return null;
}

// Generated from Graphviz `lib/common/entities.html`; keep lexicographically
// sorted because lookupNamed performs a binary search.
const html4_entities = [_]Entity{
    .{ .name = "AElig", .codepoint = 198 },
    .{ .name = "Aacute", .codepoint = 193 },
    .{ .name = "Acirc", .codepoint = 194 },
    .{ .name = "Agrave", .codepoint = 192 },
    .{ .name = "Alpha", .codepoint = 913 },
    .{ .name = "Aring", .codepoint = 197 },
    .{ .name = "Atilde", .codepoint = 195 },
    .{ .name = "Auml", .codepoint = 196 },
    .{ .name = "Beta", .codepoint = 914 },
    .{ .name = "Ccedil", .codepoint = 199 },
    .{ .name = "Chi", .codepoint = 935 },
    .{ .name = "Dagger", .codepoint = 8225 },
    .{ .name = "Delta", .codepoint = 916 },
    .{ .name = "ETH", .codepoint = 208 },
    .{ .name = "Eacute", .codepoint = 201 },
    .{ .name = "Ecirc", .codepoint = 202 },
    .{ .name = "Egrave", .codepoint = 200 },
    .{ .name = "Epsilon", .codepoint = 917 },
    .{ .name = "Eta", .codepoint = 919 },
    .{ .name = "Euml", .codepoint = 203 },
    .{ .name = "Gamma", .codepoint = 915 },
    .{ .name = "Iacute", .codepoint = 205 },
    .{ .name = "Icirc", .codepoint = 206 },
    .{ .name = "Igrave", .codepoint = 204 },
    .{ .name = "Iota", .codepoint = 921 },
    .{ .name = "Iuml", .codepoint = 207 },
    .{ .name = "Kappa", .codepoint = 922 },
    .{ .name = "Lambda", .codepoint = 923 },
    .{ .name = "Mu", .codepoint = 924 },
    .{ .name = "Ntilde", .codepoint = 209 },
    .{ .name = "Nu", .codepoint = 925 },
    .{ .name = "OElig", .codepoint = 338 },
    .{ .name = "Oacute", .codepoint = 211 },
    .{ .name = "Ocirc", .codepoint = 212 },
    .{ .name = "Ograve", .codepoint = 210 },
    .{ .name = "Omega", .codepoint = 937 },
    .{ .name = "Omicron", .codepoint = 927 },
    .{ .name = "Oslash", .codepoint = 216 },
    .{ .name = "Otilde", .codepoint = 213 },
    .{ .name = "Ouml", .codepoint = 214 },
    .{ .name = "Phi", .codepoint = 934 },
    .{ .name = "Pi", .codepoint = 928 },
    .{ .name = "Prime", .codepoint = 8243 },
    .{ .name = "Psi", .codepoint = 936 },
    .{ .name = "Rho", .codepoint = 929 },
    .{ .name = "Scaron", .codepoint = 352 },
    .{ .name = "Sigma", .codepoint = 931 },
    .{ .name = "THORN", .codepoint = 222 },
    .{ .name = "Tau", .codepoint = 932 },
    .{ .name = "Theta", .codepoint = 920 },
    .{ .name = "Uacute", .codepoint = 218 },
    .{ .name = "Ucirc", .codepoint = 219 },
    .{ .name = "Ugrave", .codepoint = 217 },
    .{ .name = "Upsilon", .codepoint = 933 },
    .{ .name = "Uuml", .codepoint = 220 },
    .{ .name = "Xi", .codepoint = 926 },
    .{ .name = "Yacute", .codepoint = 221 },
    .{ .name = "Yuml", .codepoint = 376 },
    .{ .name = "Zeta", .codepoint = 918 },
    .{ .name = "aacute", .codepoint = 225 },
    .{ .name = "acirc", .codepoint = 226 },
    .{ .name = "acute", .codepoint = 180 },
    .{ .name = "aelig", .codepoint = 230 },
    .{ .name = "agrave", .codepoint = 224 },
    .{ .name = "alefsym", .codepoint = 8501 },
    .{ .name = "alpha", .codepoint = 945 },
    .{ .name = "amp", .codepoint = 38 },
    .{ .name = "and", .codepoint = 8743 },
    .{ .name = "ang", .codepoint = 8736 },
    .{ .name = "aring", .codepoint = 229 },
    .{ .name = "asymp", .codepoint = 8776 },
    .{ .name = "atilde", .codepoint = 227 },
    .{ .name = "auml", .codepoint = 228 },
    .{ .name = "bdquo", .codepoint = 8222 },
    .{ .name = "beta", .codepoint = 946 },
    .{ .name = "brvbar", .codepoint = 166 },
    .{ .name = "bull", .codepoint = 8226 },
    .{ .name = "cap", .codepoint = 8745 },
    .{ .name = "ccedil", .codepoint = 231 },
    .{ .name = "cedil", .codepoint = 184 },
    .{ .name = "cent", .codepoint = 162 },
    .{ .name = "chi", .codepoint = 967 },
    .{ .name = "circ", .codepoint = 710 },
    .{ .name = "clubs", .codepoint = 9827 },
    .{ .name = "cong", .codepoint = 8773 },
    .{ .name = "copy", .codepoint = 169 },
    .{ .name = "crarr", .codepoint = 8629 },
    .{ .name = "cup", .codepoint = 8746 },
    .{ .name = "curren", .codepoint = 164 },
    .{ .name = "dArr", .codepoint = 8659 },
    .{ .name = "dagger", .codepoint = 8224 },
    .{ .name = "darr", .codepoint = 8595 },
    .{ .name = "deg", .codepoint = 176 },
    .{ .name = "delta", .codepoint = 948 },
    .{ .name = "diams", .codepoint = 9830 },
    .{ .name = "divide", .codepoint = 247 },
    .{ .name = "eacute", .codepoint = 233 },
    .{ .name = "ecirc", .codepoint = 234 },
    .{ .name = "egrave", .codepoint = 232 },
    .{ .name = "empty", .codepoint = 8709 },
    .{ .name = "emsp", .codepoint = 8195 },
    .{ .name = "ensp", .codepoint = 8194 },
    .{ .name = "epsilon", .codepoint = 949 },
    .{ .name = "equiv", .codepoint = 8801 },
    .{ .name = "eta", .codepoint = 951 },
    .{ .name = "eth", .codepoint = 240 },
    .{ .name = "euml", .codepoint = 235 },
    .{ .name = "euro", .codepoint = 8364 },
    .{ .name = "exist", .codepoint = 8707 },
    .{ .name = "fnof", .codepoint = 402 },
    .{ .name = "forall", .codepoint = 8704 },
    .{ .name = "frac12", .codepoint = 189 },
    .{ .name = "frac14", .codepoint = 188 },
    .{ .name = "frac34", .codepoint = 190 },
    .{ .name = "frasl", .codepoint = 8260 },
    .{ .name = "gamma", .codepoint = 947 },
    .{ .name = "ge", .codepoint = 8805 },
    .{ .name = "gt", .codepoint = 62 },
    .{ .name = "hArr", .codepoint = 8660 },
    .{ .name = "harr", .codepoint = 8596 },
    .{ .name = "hearts", .codepoint = 9829 },
    .{ .name = "hellip", .codepoint = 8230 },
    .{ .name = "iacute", .codepoint = 237 },
    .{ .name = "icirc", .codepoint = 238 },
    .{ .name = "iexcl", .codepoint = 161 },
    .{ .name = "igrave", .codepoint = 236 },
    .{ .name = "image", .codepoint = 8465 },
    .{ .name = "infin", .codepoint = 8734 },
    .{ .name = "int", .codepoint = 8747 },
    .{ .name = "iota", .codepoint = 953 },
    .{ .name = "iquest", .codepoint = 191 },
    .{ .name = "isin", .codepoint = 8712 },
    .{ .name = "iuml", .codepoint = 239 },
    .{ .name = "kappa", .codepoint = 954 },
    .{ .name = "lArr", .codepoint = 8656 },
    .{ .name = "lambda", .codepoint = 955 },
    .{ .name = "lang", .codepoint = 9001 },
    .{ .name = "laquo", .codepoint = 171 },
    .{ .name = "larr", .codepoint = 8592 },
    .{ .name = "lceil", .codepoint = 8968 },
    .{ .name = "ldquo", .codepoint = 8220 },
    .{ .name = "le", .codepoint = 8804 },
    .{ .name = "lfloor", .codepoint = 8970 },
    .{ .name = "lowast", .codepoint = 8727 },
    .{ .name = "loz", .codepoint = 9674 },
    .{ .name = "lrm", .codepoint = 8206 },
    .{ .name = "lsaquo", .codepoint = 8249 },
    .{ .name = "lsquo", .codepoint = 8216 },
    .{ .name = "lt", .codepoint = 60 },
    .{ .name = "macr", .codepoint = 175 },
    .{ .name = "mdash", .codepoint = 8212 },
    .{ .name = "micro", .codepoint = 181 },
    .{ .name = "middot", .codepoint = 183 },
    .{ .name = "minus", .codepoint = 8722 },
    .{ .name = "mu", .codepoint = 956 },
    .{ .name = "nabla", .codepoint = 8711 },
    .{ .name = "nbsp", .codepoint = 160 },
    .{ .name = "ndash", .codepoint = 8211 },
    .{ .name = "ne", .codepoint = 8800 },
    .{ .name = "ni", .codepoint = 8715 },
    .{ .name = "not", .codepoint = 172 },
    .{ .name = "notin", .codepoint = 8713 },
    .{ .name = "nsub", .codepoint = 8836 },
    .{ .name = "ntilde", .codepoint = 241 },
    .{ .name = "nu", .codepoint = 957 },
    .{ .name = "oacute", .codepoint = 243 },
    .{ .name = "ocirc", .codepoint = 244 },
    .{ .name = "oelig", .codepoint = 339 },
    .{ .name = "ograve", .codepoint = 242 },
    .{ .name = "oline", .codepoint = 8254 },
    .{ .name = "omega", .codepoint = 969 },
    .{ .name = "omicron", .codepoint = 959 },
    .{ .name = "oplus", .codepoint = 8853 },
    .{ .name = "or", .codepoint = 8744 },
    .{ .name = "ordf", .codepoint = 170 },
    .{ .name = "ordm", .codepoint = 186 },
    .{ .name = "oslash", .codepoint = 248 },
    .{ .name = "otilde", .codepoint = 245 },
    .{ .name = "otimes", .codepoint = 8855 },
    .{ .name = "ouml", .codepoint = 246 },
    .{ .name = "para", .codepoint = 182 },
    .{ .name = "part", .codepoint = 8706 },
    .{ .name = "permil", .codepoint = 8240 },
    .{ .name = "perp", .codepoint = 8869 },
    .{ .name = "phi", .codepoint = 966 },
    .{ .name = "pi", .codepoint = 960 },
    .{ .name = "piv", .codepoint = 982 },
    .{ .name = "plusmn", .codepoint = 177 },
    .{ .name = "pound", .codepoint = 163 },
    .{ .name = "prime", .codepoint = 8242 },
    .{ .name = "prod", .codepoint = 8719 },
    .{ .name = "prop", .codepoint = 8733 },
    .{ .name = "psi", .codepoint = 968 },
    .{ .name = "quot", .codepoint = 34 },
    .{ .name = "rArr", .codepoint = 8658 },
    .{ .name = "radic", .codepoint = 8730 },
    .{ .name = "rang", .codepoint = 9002 },
    .{ .name = "raquo", .codepoint = 187 },
    .{ .name = "rarr", .codepoint = 8594 },
    .{ .name = "rceil", .codepoint = 8969 },
    .{ .name = "rdquo", .codepoint = 8221 },
    .{ .name = "real", .codepoint = 8476 },
    .{ .name = "reg", .codepoint = 174 },
    .{ .name = "rfloor", .codepoint = 8971 },
    .{ .name = "rho", .codepoint = 961 },
    .{ .name = "rlm", .codepoint = 8207 },
    .{ .name = "rsaquo", .codepoint = 8250 },
    .{ .name = "rsquo", .codepoint = 8217 },
    .{ .name = "sbquo", .codepoint = 8218 },
    .{ .name = "scaron", .codepoint = 353 },
    .{ .name = "sdot", .codepoint = 8901 },
    .{ .name = "sect", .codepoint = 167 },
    .{ .name = "shy", .codepoint = 173 },
    .{ .name = "sigma", .codepoint = 963 },
    .{ .name = "sigmaf", .codepoint = 962 },
    .{ .name = "sim", .codepoint = 8764 },
    .{ .name = "spades", .codepoint = 9824 },
    .{ .name = "sub", .codepoint = 8834 },
    .{ .name = "sube", .codepoint = 8838 },
    .{ .name = "sum", .codepoint = 8721 },
    .{ .name = "sup", .codepoint = 8835 },
    .{ .name = "sup1", .codepoint = 185 },
    .{ .name = "sup2", .codepoint = 178 },
    .{ .name = "sup3", .codepoint = 179 },
    .{ .name = "supe", .codepoint = 8839 },
    .{ .name = "szlig", .codepoint = 223 },
    .{ .name = "tau", .codepoint = 964 },
    .{ .name = "there4", .codepoint = 8756 },
    .{ .name = "theta", .codepoint = 952 },
    .{ .name = "thetasym", .codepoint = 977 },
    .{ .name = "thinsp", .codepoint = 8201 },
    .{ .name = "thorn", .codepoint = 254 },
    .{ .name = "tilde", .codepoint = 732 },
    .{ .name = "times", .codepoint = 215 },
    .{ .name = "trade", .codepoint = 8482 },
    .{ .name = "uArr", .codepoint = 8657 },
    .{ .name = "uacute", .codepoint = 250 },
    .{ .name = "uarr", .codepoint = 8593 },
    .{ .name = "ucirc", .codepoint = 251 },
    .{ .name = "ugrave", .codepoint = 249 },
    .{ .name = "uml", .codepoint = 168 },
    .{ .name = "upsih", .codepoint = 978 },
    .{ .name = "upsilon", .codepoint = 965 },
    .{ .name = "uuml", .codepoint = 252 },
    .{ .name = "weierp", .codepoint = 8472 },
    .{ .name = "xi", .codepoint = 958 },
    .{ .name = "yacute", .codepoint = 253 },
    .{ .name = "yen", .codepoint = 165 },
    .{ .name = "yuml", .codepoint = 255 },
    .{ .name = "zeta", .codepoint = 950 },
    .{ .name = "zwj", .codepoint = 8205 },
    .{ .name = "zwnj", .codepoint = 8204 },
};

test "HTML 4 decoder handles named numeric and preserved references" {
    const allocator = std.testing.allocator;
    const decoded = try decodeAlloc(
        allocator,
        "&alpha;&forall;&amp;&#65;&#x1F642;&bogus;&apos;&#0;&#xD800;&alpha",
    );
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(
        "α∀&A🙂&bogus;&apos;&#0;&#xD800;&alpha",
        decoded,
    );
}

test "HTML 4 decoder is single pass and case sensitive" {
    const allocator = std.testing.allocator;
    const decoded = try decodeAlloc(allocator, "&#38;alpha; &Alpha; &ALPHA; &thetasym;");
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("&alpha; Α &ALPHA; ϑ", decoded);
}
