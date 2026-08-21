# Seq

LuaJIT-optimized, lazy sequence combinator library.
Built on Lua's `gen/param/state` iterator triplet.

```lua
local Seq = require("seq")
local result = Seq.from({1,2,3,4,5})
    :map(function(x) return x * 2 end)
    :filter(function(x) return x > 4 end)
    :take(2)
    :collect()
-- {6, 8}
```

## Design

## Design

Every sequence is a `gen/param/state` triplet: `state', value = gen(param, state)`, where `state' == nil` marks the end. `Seq` wraps the triplet to support `:` method chaining. Combinators are closure factories: each one wraps the previous stage's `gen` and returns a new triplet. A pipeline does no work until a terminal operation (like `:collect()`) drives it.

## API

### Sources

| Method | Description |
| --- | --- |
| `Seq.from(t)` | Single-value sequence over an array |
| `Seq.from_pairs(t)` | Key-value sequence over a table |
| `Seq.range(from, to [, step])` | Range sequence with optional step (default step = 1) |
| `Seq.repeat_(v [, n])` | Repeat value `v` `n` times, or forever if `n` is omitted |

### Single-Value Combinators

| Method | Description |
| --- | --- |
| `seq:map(fn)` | Transform each element through `fn(v)` |
| `seq:filter(pred)` | Keep only elements where `pred(v)` is true |
| `seq:take(n)` | Yield at most the first `n` elements |
| `seq:take_while(pred)` | Yield elements until `pred(v)` first fails |
| `seq:drop(n)` | Skip the first `n` elements, then yield the rest |
| `seq:drop_while(pred)` | Skip elements while `pred(v)` holds, then yield the rest |
| `seq:scan(fn, init)` | Running fold (`init` required), yielding intermediate accumulators |
| `seq:chain(other)` | Yield every element of `self`, then every element of `other` (single-use) |
| `seq:enumerate()` | Yields `(index, value)` pairs, index starting at 1 |
| `seq:zip(other)` | Yields `(a, b)` pairs, stopping when either side ends |
| `seq:flat_map(fn)` | `fn(v)` returns a `Seq` or plain array table; each inner sequence is fully drained before advancing |

### Key/Value Combinators

| Method | Description |
| --- | --- |
| `seq:map2(fn)` | `fn(k, v) -> new_v`; key passes through unchanged |
| `seq:filter2(pred)` | Keep only `(k, v)` pairs where `pred(k, v)` is true |
| `seq:scan2(fn, init)` | Running fold over `(k, v)` pairs (`init` required) |
| `seq:chain2(other)` | Yield every `(k, v)` pair of `self`, then every pair of `other` (single-use) |
| `seq:values()` | Project down to a single-value `Seq` of just the values |
| `seq:keys()` | Project down to a single-value `Seq` of just the keys |

### Terminal Operations

| Method | Description |
| --- | --- |
| `seq:collect([size_hint])` | Collect single-value sequence into an array table (`size_hint` pre-allocates) |
| `seq:collect2([size_hint])` | Collect `zip()` / `enumerate()` sequence into array of `{a, b}` pairs |
| `seq:collect_pairs([size_hint])` | Collect `from_pairs` family sequence into array of `{k, v}` pairs |
| `seq:reduce(fn, init)` | Fold `fn(acc, v)` over every element (`init` required) |
| `seq:each(fn)` | Call `fn(v)` for every element, discarding the result |
| `seq:length()` | Count the elements in the sequence |
| `seq:find(pred)` | Return the first element for which `pred(v)` is true, or `nil` if none match |
| `seq:any(pred)` | True if `pred(v)` holds for at least one element |
| `seq:all(pred)` | True if `pred(v)` holds for every element or the sequence is empty |
