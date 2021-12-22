const std = @import("std");
const base32 = @import("base32");
const t = std.testing;
const stdout = std.io.getStdOut().writer();

pub const ULID = struct {
    const Self = @This();

    data: [16]u8 = [_]u8{0} ** 16,

    pub fn random(rand: std.rand.Random) ULID {
        // Get a calendar timestamp, in milliseconds, relative to UTC 1970-01-01.
        return randomWithTimestamp(rand, std.time.milliTimestamp());
    }

    pub fn randomWithTimestamp(rand: std.rand.Random, unixTimestamp: i64) ULID {
        var n = ULID{};
        rand.bytes(n.data[6..]);
        const ts = @intCast(u48, unixTimestamp);
        std.mem.writeIntBig(u48, n.data[0..6], ts);
        return n;
    }

    pub fn timestamp(self: *const Self) i64 {
        return @intCast(i64, std.mem.readIntBig(u48, self.data[0..6]));
    }

    pub fn payload(self: *const Self) *const [10]u8 {
        return self.data[6..];
    }

    pub fn parse(data: []const u8) !ULID {
        if (data.len < 26) {
            return error.InvalidLength;
        }
        var n = ULID{};
        _ = try base32.crockford_encoding.decode(&n.data, data[0..26]);
        return n;
    }

    pub fn format(self: *const Self, dest: *[26]u8) []const u8 {
        return base32.crockford_encoding.encode(dest, &self.data);
    }

    pub fn fmt(self: *const Self) std.fmt.Formatter(formatULID) {
        return .{ .data = self };
    }
};

pub fn formatULID(
    ulid: *const ULID,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;
    var buf: [26]u8 = undefined;
    _ = ulid.format(&buf);
    try writer.writeAll(&buf);
}

test "parse" {
    const a = try ULID.parse("01BX5ZZKBKACTAV9WEVGEMMVRY");
    //std.debug.print("payload[{s}]\n", .{std.fmt.fmtSliceHexUpper(a.payload())});
    try t.expectEqual(@as(i64, 377202144092), a.timestamp());
    var buf: [16]u8 = undefined;
    const expected = try std.fmt.hexToBytes(&buf, "D4CD2B69E3B707529B00");
    try t.expectEqualSlices(u8, expected, a.payload());

    if (ULID.parse("***************************")) |_| {
        return error.ExpectedError;
    } else |err| if (err != error.CorruptImput) {
        return err;
    }

    if (ULID.parse("123")) |_| {
        return error.ExpectedError;
    } else |err| if (err != error.InvalidLength) {
        return err;
    }

    if (ULID.parse("fffffffffffffffffffffffffff")) |_| {
        return error.ExpectedError;
    } else |err| if (err != error.CorruptImput) {
        return err;
    }

    const max = try ULID.parse("ZZZZZZZZZZZZZZZZZZZZZZZZZZ");
    try t.expectEqual(@as(i64, 281474976710655), max.timestamp());
    //std.debug.print("payload[{s}]\n", .{std.fmt.fmtSliceHexUpper(max.payload())});
    try t.expectEqualSlices(u8, &[_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00 }, max.payload());
}

test "formatter" {
    const a = ULID{};
    var fmtbuf: [26]u8 = undefined;
    _ = try std.fmt.bufPrint(&fmtbuf, "{s}", .{a.fmt()});
    try t.expectEqualSlices(u8, "00000000000000000000000000", &fmtbuf);
}

test "random" {
    const seed_time = 1469918176385;
    var prng = std.rand.DefaultPrng.init(0);
    const a = ULID.randomWithTimestamp(prng.random(), seed_time);
    try t.expectEqual(@as(i64, seed_time), a.timestamp());
    var buf: [16]u8 = undefined;
    const expected = try std.fmt.hexToBytes(&buf, "DF230B49615D175307D5");
    //std.debug.print("payload[{s}]\n", .{std.fmt.fmtSliceHexUpper(a.payload())});
    try t.expectEqualSlices(u8, expected, a.payload());
}
