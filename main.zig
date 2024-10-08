const std = @import("std");
const os = std.os.linux;
const mem = std.mem;
const fs = std.fs;

pub fn main() !void {
    //
    // Setup RNG
    //
    var seed: u64 = undefined;
    _ = os.getrandom(mem.asBytes(&seed), @sizeOf(usize), 0);
    var prng = std.rand.DefaultPrng.init(seed);
    const rand = prng.random();

    //
    // Read $HOME
    //
    var home: [*:0]const u8 = "HOME=/home/unknown";
    outer: for (std.os.environ) |env| {
        const match = "HOME=";
        var i: usize = 0;
        for (env, 0..match.len) |c, _| {
            if (c == 0) continue :outer;
            if (c != match[i]) continue :outer;
            i += 1;
        }
        if (i != match.len) continue;

        home = @ptrCast(env);
        break;
    }

    //
    // Concat path to HOME
    //
    var filepath_buf: [1024]u8 = undefined;
    var cont: usize = 0;
    for (0..filepath_buf.len) |i| {
        if (home[i] == 0) {
            cont = i;
            break;
        }
        filepath_buf[i] = home[i];
    }
    const rest = "/.config/helix/themes/nigel.toml";
    mem.copyForwards(u8, filepath_buf[cont..], rest);
    const filepath = filepath_buf[5..(cont + rest.len)];

    //
    // Open file
    //
    const file = try fs.openFileAbsolute(filepath, fs.File.OpenFlags{ .mode = .read_write });
    defer file.close();
    const len = try file.getEndPos();

    //
    // MMAP file
    //
    const map_result = os.mmap(null, len, os.PROT.WRITE, os.MAP{ .TYPE = .SHARED }, file.handle, 0);
    if (map_result == -1) {
        return error.FailedToMap;
    }
    const bytes_ptr: [*]u8 = @ptrFromInt(map_result);
    defer _ = os.munmap(bytes_ptr, len);
    const bytes = bytes_ptr[0..len];

    //
    // Collect themes
    //
    const themes_cap = 32;
    var themes: [themes_cap][]u8 = undefined;
    var themes_len: usize = 0;

    var start: usize = 0;
    for (bytes, 0..) |b, i| {
        if (b == '\n') {
            const theme = bytes[start..i];

            if (!mem.containsAtLeast(u8, theme, 1, "inherits =")) {
                break;
            }

            themes[themes_len] = theme;
            themes_len += 1;
            if (themes_len >= themes_cap) {
                break;
            }

            start = i + 1;
        }
    }

    //
    // Unset all themes
    //
    for (themes[0..themes_len]) |theme| {
        theme[0] = '#';
    }

    //
    // Pick random theme
    //
    const picked = rand.intRangeLessThan(usize, 0, themes_len);
    themes[picked][0] = ' ';
}
