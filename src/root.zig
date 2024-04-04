const std = @import("std");
const mecha = @import("mecha");

pub const Charset = enum(u8) {
    AnsiLatin = 0x00,
    SysDefault = 0x01,
    Symbol = 0x02,
    AppleRoman = 0x4d,
    AnsiJapShiftJis = 0x80,
    AnsiKorHangul = 0x81,
    AnsiKorJohab = 0x82,
    AnsiChineseGbk = 0x86,
    AnsiChineseBig5 = 0x88,
    AnsiGreek = 0xa1,
    AnsiTurkish = 0xa2,
    AnsiVietnamese = 0xa3,
    AnsiHebrew = 0xb1,
    AnsiArabic = 0xb2,
    AnsiBaltic = 0xba,
    AnsiCyrillic = 0xcc,
    AnsiThai = 0xde,
    AnsiLatinIi = 0xee,
    OemLatinI = 0xff,
};

const charset_strings_parser = blk: {
    const fields = @typeInfo(Charset).Enum.fields;
    var values: [fields.len]mecha.Parser([]const u8) = undefined;
    for (0..fields.len) |i| {
        var underscores: usize = 0;
        for (fields[i].name[1..]) |c|
            underscores += @intFromBool(std.ascii.isUpper(c));

        var buf: [fields[i].name.len + underscores]u8 = undefined;
        buf[0] = std.ascii.toLower(fields[i].name[0]);
        var j: usize = 1;
        for (fields[i].name[1..]) |c| {
            if (std.ascii.isUpper(c)) {
                buf[j + 0] = '_';
                buf[j + 1] = std.ascii.toLower(c);
                j += 2;
            } else {
                buf[j] = c;
                j += 1;
            }
        }
        std.debug.assert(j == buf.len);
        const x = buf;
        values[i] = mecha.string(&x);
    }
    break :blk values;
};

const charset_enum_parser = mecha.enumeration(Charset);

const charset_parser = mecha.combine(.{
    mecha.combine(.{
        mecha.string("charset"),
        mecha.ascii.char(':'),
        mecha.many(mecha.ascii.whitespace, .{ .collect = false }),
    }).discard(),
    mecha.oneOf(charset_strings_parser).convert(charsetParser),
});

pub fn charsetParser(alloc: std.mem.Allocator, charset: []const u8) mecha.Error!Charset {
    var values = std.mem.tokenizeScalar(u8, charset, '_');
    var words = std.ArrayList([]const u8).init(alloc);
    defer words.deinit();

    while (values.next()) |word| {
        var other = try alloc.alloc(u8, word.len);
        @memcpy(other, word);
        other[0] = std.ascii.toUpper(word[0]);
        try words.append(other);
    }
    defer {
        for (words.items) |word| {
            alloc.free(word);
        }
    }
    const joined = try std.mem.join(alloc, "", words.items);
    defer alloc.free(joined);
    return (try charset_enum_parser.parse(alloc, joined)).value;
}

test "charset parset" {
    try std.testing.expectEqual(.AnsiLatin, (try charset_parser.parse(std.testing.allocator, "charset: ansi_latin")).value);
    try std.testing.expectEqual(.AnsiLatinIi, (try charset_parser.parse(std.testing.allocator, "charset: ansi_latin_ii")).value);
    try std.testing.expectEqual(.AnsiChineseBig5, (try charset_parser.parse(std.testing.allocator, "charset: ansi_chinese_big5")).value);
    try std.testing.expectEqual(.AppleRoman, (try charset_parser.parse(std.testing.allocator, "charset: apple_roman")).value);
}

test "this should not fail but fails" {
    try std.testing.expectEqual(.AppleRoman, (try charset_parser.parse(std.testing.allocator, "charset: apple_roman")).value);
}
