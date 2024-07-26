const std = @import("std");
const curl = @import("curl");
const Easy = curl.Easy;
const println = @import("util.zig").println;

fn iterateHeaders(easy: Easy) !void {
    // Reset old options, e.g. headers.
    easy.reset();

    const resp = try easy.get("https://httpbin.org/response-headers?X-Foo=1&X-Foo=2&X-Foo=3");
    defer resp.deinit();

    std.debug.print("Iterating all headers...\n", .{});
    {
        var iter = try resp.iterateHeaders(.{});
        while (try iter.next()) |header| {
            std.debug.print("  {s}: {s}\n", .{ header.name, header.get() });
        }
    }

    // Iterating X-Foo only
    {
        var iter = try resp.iterateHeaders(.{ .name = "X-Foo" });
        const expected_values = .{ "1", "2", "3" };
        inline for (expected_values) |expected| {
            const header = try iter.next() orelse unreachable;
            try std.testing.expectEqualStrings(header.get(), expected);
        }
        try std.testing.expect((try iter.next()) == null);
    }
}

fn iterateRedirectedHeaders(easy: Easy) !void {
    // Reset old options, e.g. headers.
    easy.reset();

    try easy.setFollowLocation(true);
    const resp = try easy.get("https://httpbin.org/redirect/1");
    defer resp.deinit();

    const redirects = try resp.getRedirectCount();
    try std.testing.expectEqual(redirects, 1);

    for (0..redirects + 1) |i| {
        std.debug.print("Request #{} headers:\n", .{i});
        var iter = try resp.iterateHeaders(.{ .request = i });
        while (try iter.next()) |header| {
            std.debug.print("  {s}: {s}\n", .{ header.name, header.get() });
        }
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const ca_bundle = try curl.allocCABundle(allocator);
    defer ca_bundle.deinit();
    const easy = try Easy.init(allocator, .{
        .ca_bundle = ca_bundle,
    });
    defer easy.deinit();

    if (comptime !curl.hasParseHeaderSupport()) {
        std.debug.print("Libcurl version too old, don't support parse headers.\n", .{});
        return;
    }

    println("Iterate headers demo");
    try iterateHeaders(easy);

    println("Redirected headers demo");
    try iterateRedirectedHeaders(easy);
}
