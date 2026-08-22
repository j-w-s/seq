# Installing Seq

## Option 1: LuaRocks

From the project root:

```sh
sudo luarocks make seq-scm-1.rockspec          # system-wide
luarocks make --local seq-scm-1.rockspec       # user-local
```

Then, in any script:

```lua
local Seq = require("seq")
local result = Seq.from({1,2,3}):map(function(x) return x * 2 end):collect()
```

If installed with `--local`, run:

```sh
eval "$(luarocks path)"
```

(or add the equivalent to your shell profile) so `LUA_PATH`/`LUA_CPATH`
point at `~/.luarocks`. Without this, `require` won't find the
installed modules.

## Option 2: Direct Vendor

Copy `seq.lua` and the entire `src/` directory into your project, then
point `package.path` at both locations before the first `require`:

```lua
package.path = "./?.lua;./src/?.lua;" .. package.path
local Seq = require("seq")
```

Both path entries are required: `seq.lua` does `require("sources")`,
`require("combinators")`, etc. as bare module names, and those files
live in `src/`, so `src/` needs its own entry. Omitting `src/?.lua`
fails with:

```
module 'sources' not found:
    no field package.preload['sources']
    no file './sources.lua'
    ...
```

## Requirements

LuaJIT 2.1, not reference/PUC-Rio Lua.

## Verifying Installation

```sh
luajit -e 'local Seq = require("seq"); print(Seq.from({1,2,3}):map(function(x) return x*2 end):collect()[2])'
# should print: 4
```