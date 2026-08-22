rockspec_format = "3.0"
package = "seq"
version = "scm-1"
source = {
   url = "git+https://github.com/j-w-s/seq.git",
}
description = {
   maintainer = "j-w-s",
   summary = "LuaJIT-optimized, lazy sequence combinator library",
   detailed = [[
      LuaJIT-optimized, lazy sequence combinator library built on Lua's `gen/param/state` iterator triplet.
   ]],
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
}
test_dependencies = {
   "busted",
}
test = {
   type = "command",
   command = "busted",
}
build = {
   type = "builtin",
   modules = {
      seq               = "seq.lua",
      core              = "src/core.lua",
      protopool         = "src/protopool.lua",
      sources           = "src/sources.lua",
      combinators       = "src/combinators.lua",
      combinators_pairs = "src/combinators_pairs.lua",
      terminal          = "src/terminal.lua",
   },
}