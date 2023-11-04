const std = @import("std");

pub fn longestApprovedAlphabeticGrapheme(slice: []const u8) ?[]const u8 {
    const State = enum { start, e };

    var state: State = .start;
    var utf8_it = std.unicode.Utf8View.initUnchecked(slice).iterator();
    var byte_len: usize = 0;
    while (utf8_it.nextCodepoint()) |codepoint| {
        const cur_codepoint_byte_len = std.unicode.utf8CodepointSequenceLength(codepoint) catch unreachable;
        byte_len += cur_codepoint_byte_len;
        switch (state) {
            .start => {
                var piece = slice[0..byte_len];

                switch (codepoint) {
                    'a'...'z', 'A'...'Z', '_' => state = .e,
                    'ě', 'Ě' => return piece,
                    'š', 'Š' => return piece,
                    'č', 'Č' => return piece,
                    'ř', 'Ř' => return piece,
                    'ž', 'Ž' => return piece,
                    'ý', 'Ý' => return piece,
                    'á', 'Á' => return piece,
                    'í', 'Í' => return piece,
                    'é', 'É' => return piece,
                    'ň', 'Ň' => return piece,
                    'ú', 'Ú' => return piece,
                    'ů', 'Ů' => return piece,
                    else => return null,
                }
            },
            .e => return switch (codepoint) {
                '\u{030C}' => slice[0..byte_len],
                '\u{030A}' => slice[0..byte_len],
                '\u{0301}' => slice[0..byte_len],
                else => slice[0 .. byte_len - cur_codepoint_byte_len],
            },
        }
    }

    switch (state) {
        .e => return slice[0..byte_len],
        else => {},
    }

    return null;
}

test {
    try std.testing.expect(null == longestApprovedAlphabeticGrapheme("ó"));
}
