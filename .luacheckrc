unused_args     = false
redefined       = false
max_line_length = false

globals = {
    "ngx",
}

not_globals = {
    "string.len",
    "table.getn",
}

include_files = {
  "**/*.lua",
  "**/*.rockspec",
  ".busted",
  ".luacheckrc",
}

files["spec/**/*.lua"] = {
    std = "+busted",
}

exclude_files = {
    -- GH Actions Lua Environment
    ".lua",
    ".luarocks",
    ".install",
	"rockspecs/luaexpat-1.3.3-1.rockspec" -- has whitespace issues but already published
}
