--[[
Prototype pools for combinator gen closures.

Rotating prototypes isolates trace caches per closure to avoid maxtrace
eviction. This does NOT bypass unrolling limits (callunroll/recunroll).
]]

local M = {}

--[[
Pool size stays below hotloop (56).

Distinct variants ensure each closure can form its own root trace
without interfering with others' trace state.
]]
M.DEFAULT_POOL_SIZE = 48

--[[
Build a round-robin pool of distinct prototype closures.
]]
function M.new_pool(size, template_fn)
  assert(type(size) == "number" and size >= 1, "new_pool: size must be >= 1")
  assert(type(template_fn) == "function", "new_pool: template_fn must be a function")

  local pool = {}
  for i = 1, size do
    local src = template_fn(i)
    local chunk, err = load(src, "=seq.protopool.variant_" .. i)
    if not chunk then
      error(("protopool.new_pool: template %d failed to compile: %s\n%s")
        :format(i, tostring(err), src))
    end
    pool[i] = chunk()
  end

  local idx = 0
  return function()
    idx = idx % size + 1
    return pool[idx]
  end
end

return M