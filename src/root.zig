const std = @import("std");
const builtin = @import("builtin");
const backtrace = @import("backtrace");

const File = std.fs.File;

var file: ?File = null;
var mutex = std.Thread.Mutex{};
var mode: Mode = .file;
const LOGNAME = "log.txt";

const Mode = enum {
    file,
    stderr,
};

fn ensureFileOpened() void {
    if (mode != .file) return;
    if (file != null) return;

    const truncate = !builtin.is_test;

    file = std.fs.cwd().createFile(LOGNAME, .{ .truncate = truncate }) catch |e| {
        mode = .stderr;
        err("Failed to create log file: {s}, err: {}", .{ LOGNAME, e });
        return;
    };
}

pub fn info(comptime format: []const u8, args: anytype) void {
    //if (builtin.mode != .Debug) {
    //    return;
    //}
    ensureFileOpened();

    switch (mode) {
        .file => {
            const writer = file.?.writer();
            mutex.lock();
            defer mutex.unlock();

            nosuspend writer.print("INFO: " ++ format ++ "\n", args) catch return;
        },
        .stderr => {
            const writer = std.io.getStdErr().writer();
            std.debug.getStderrMutex().lock();
            defer std.debug.getStderrMutex().unlock();

            nosuspend writer.print("INFO: " ++ format ++ "\n", args) catch return;
        },
    }
}

pub fn err(comptime format: []const u8, args: anytype) void {
    ensureFileOpened();

    var addrs: [32]usize = undefined;
    const stacktrace = backtrace.backtrace(addrs[0..]);

    switch (mode) {
        .file => {
            const writer = file.?.writer();
            mutex.lock();
            defer mutex.unlock();

            nosuspend writer.print("ERROR: " ++ format ++ "\n", args) catch return;
            if (!builtin.strip_debug_info) {
                const debug_info = std.debug.getSelfDebugInfo() catch |e| {
                    nosuspend writer.print("ERROR: Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(e)}) catch return;
                    return;
                };
                var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer arena.deinit();
                std.debug.writeStackTrace(stacktrace, writer, arena.allocator(), debug_info, .no_color) catch |e| {
                    nosuspend writer.print("ERROR: Unable to dump stack trace: Failed to writeStackTrace: {s}\n", .{@errorName(e)}) catch return;
                    return;
                };
            }
        },
        .stderr => {
            const writer = std.io.getStdErr().writer();
            std.debug.getStderrMutex().lock();
            defer std.debug.getStderrMutex().unlock();

            nosuspend writer.print("ERROR: " ++ format ++ "\n", args) catch return;
            std.debug.dumpStackTrace(stacktrace);
        },
    }
}

test "log" {
    info("Some info: {}!", .{55});
    err("Some very mean error: {s}!", .{"All your errors are belong to us!"});
}

