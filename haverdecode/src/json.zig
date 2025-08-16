const std = @import("std");
// Adapted from nxjson: https://github.com/thestr4ng3r/nxjson

pub const NXJsonType = enum {
    NX_JSON_NULL, // this is null value
    NX_JSON_OBJECT, // this is an object; properties can be found in child nodes
    NX_JSON_ARRAY, // this is an array; items can be found in child nodes
    NX_JSON_STRING, // this is a string; value can be found in text_value field
    NX_JSON_INTEGER, // this is an integer; value can be found in int_value field
    NX_JSON_DOUBLE, // this is a double; value can be found in dbl_value field
    NX_JSON_BOOL, // this is a boolean; value can be found in int_value field
    NX_JSON_FLOAT,
};

pub const NXJson = struct {
    type: NXJsonType,
    key: []const u8,
    text_value: []const u8,
    int_value: usize,
    dbl_value: f64,
    length: usize,
    children: struct {
        length: usize,
        first: ?*NXJson,
        last: ?*NXJson,
    },
    next: ?*NXJson,
};

const ParseKeyResult = struct {
    key: []const u8,
    new_pos: usize,
};

fn createJson(allocator: std.mem.Allocator, kind: NXJsonType, key: []const u8, parent: *NXJson) !*NXJson {
    const nx_json = try allocator.create(NXJson);
    nx_json.* = std.mem.zeroInit(NXJson, .{
        .type = kind,
        .key = key,
    });

    if (parent.children.last == null) {
        parent.children.first = nx_json;
        parent.children.last = nx_json;
    } else {
        parent.children.last.?.next = nx_json;
        parent.children.last = nx_json;
    }

    parent.children.length += 1;

    return nx_json;
}

fn unescapeString(input: []const u8) !struct { key: []const u8, bytesConsumed: usize } {
    var end_idx: usize = 0;
    while (end_idx < input.len and input[end_idx] != '"') : (end_idx += 1) {}
    if (end_idx >= input.len) return error.UnexpectedChars;
    return .{
        .key = input[0..end_idx],
        .bytesConsumed = end_idx + 1, // +1 to skip closing quote
    };
}

fn parseKey(text: []const u8, start_pos: usize) !ParseKeyResult {
    var pos = start_pos;

    while (pos < text.len) {
        const current = text[pos];
        // std.debug.print("parseKey -> current: {c}\n", .{current});
        pos += 1;

        switch (current) {
            '"' => {
                const result = try unescapeString(text[pos..]);
                pos += result.bytesConsumed;

                if (pos < text.len and text[pos] == ':') {
                    return ParseKeyResult{
                        .key = result.key,
                        .new_pos = pos + 1,
                    };
                }
            },
            '}' => {
                return ParseKeyResult{
                    .key = "",
                    .new_pos = pos - 1,
                };
            },
            ',' => continue,
            else => return error.UnexpectedCharacter,
        }
    }

    return error.UnexpectedEndOfKeyText;
}

fn parseValue(allocator: std.mem.Allocator, parent: *NXJson, key: []const u8, text: []const u8, start_pos: usize) !usize {
    var pos = start_pos;

    while (pos < text.len) {
        const char = text[pos];

        // std.debug.print("parseValue -> char at pos {}: {c}\n", .{ pos, char });

        switch (char) {
            // \0 invalid char? Should return error?
            // Skip
            ' ', '\t', '\n', '\r', ',' => {
                pos += 1;
                continue;
            },
            '{' => {
                // New JSON object
                const json = try createJson(allocator, NXJsonType.NX_JSON_OBJECT, key, parent);
                // Move ptr
                pos += 1;

                while (true) {
                    const key_result = try parseKey(text, pos);
                    if (key_result.key.len == 0) {
                        return key_result.new_pos + 1;
                    }

                    const new_key = key_result.key;
                    pos = key_result.new_pos;

                    // std.debug.print("parseValue -> key result: {s}\n", .{key_result.key});

                    // Check for end of object
                    if (pos >= text.len) return error.UnexpectedEndOfText;
                    if (text[pos] == '}') {
                        // std.debug.print("end of obj\n", .{});
                        return pos + 1; // Return position after '}'
                    }

                    // Parse value recursively
                    pos = try parseValue(allocator, json, new_key, text, pos);
                }
            },
            '[' => {
                // New array

                const json = try createJson(allocator, NXJsonType.NX_JSON_ARRAY, key, parent);
                pos += 1;

                while (true) {
                    pos = try parseValue(allocator, json, "0", text, pos);
                    if (text[pos] == ']') {
                        return pos + 1;
                    }
                }
            },
            // ']' => text,
            // '"' => {
            //     // New string
            // },
            '-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
                // Parse numbers

                var json = try createJson(allocator, NXJsonType.NX_JSON_FLOAT, key, parent);

                // std.debug.print("text[{}]: {c}\n", .{ pos + 2, text[pos + 2] });

                var end_idx: usize = 0;

                while (true) {
                    if (text[pos + end_idx] == ',' or text[pos + end_idx] == '}') {
                        // std.debug.print("wat??\tend_idx: {} {c}\n", .{ end_idx, text[pos + end_idx] });
                        break;
                    }

                    end_idx += 1;
                }

                if (end_idx > text.len) return error.UrLogicSux;

                const parsed_float = try std.fmt.parseFloat(f32, text[pos .. pos + end_idx]);

                // std.debug.print("parsed float: {d}\n", .{parsed_float});

                json.dbl_value = parsed_float;

                return pos + end_idx;
            },
            // // Don't care about true/false/null
            // 't', 'f', 'n' => continue,
            else => continue,
        }
    }

    return error.UnexpectedEndOfText;
}

pub fn parse(allocator: std.mem.Allocator, text: []const u8) !struct { json: NXJson, arena: std.heap.ArenaAllocator } {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const arena_allocator = arena.allocator();

    var nx_json = std.mem.zeroInit(NXJson, .{});
    _ = try parseValue(arena_allocator, &nx_json, "0", text, 0);

    return .{ .json = nx_json, .arena = arena };
}
