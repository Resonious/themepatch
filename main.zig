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
    // Open file
    //
    const file = try fs.openFileAbsolute("/home/nigel/.config/helix/themes/nigel.toml", fs.File.OpenFlags{ .mode = .read_write });
    defer file.close();
    const len = try file.getEndPos();

    //
    // MMAP to read file
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
