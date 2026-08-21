--[[
The key/value (from_pairs) combinator family. Independent from the
single-value family in combinators.lua.
]]

local core = require("core")
local protopool = require("protopool")
local wrap = core.wrap
local Seq = core.Seq

local POOL_SIZE = protopool.DEFAULT_POOL_SIZE

local MAP2_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, fn)
      local function map2_gen_%d(param, state)
        local k, v = prev_gen(param, state)
        if k == nil then return nil end
        return k, fn(k, v)
      end
      return map2_gen_%d
    end
  ]], i, i)
end)

--[[
fn(k, v) -> new_v. Key passes through unchanged.
]]
function Seq:map2(fn)
  if type(fn) ~= "function" then error("map2: fn must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = MAP2_POOL()
  return wrap(make_gen(prev_gen, fn), prev_param, self.state)
end

local FILTER2_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, pred)
      local filter2_gen_%d
      filter2_gen_%d = function(param, state)
        local k, v = prev_gen(param, state)
        if k == nil then return nil end
        if pred(k, v) then return k, v end
        return filter2_gen_%d(param, k)
      end
      return filter2_gen_%d
    end
  ]], i, i, i, i)
end)

--[[
Keep only (k, v) pairs where pred(k, v) is true.
]]
function Seq:filter2(pred)
  if type(pred) ~= "function" then error("filter2: pred must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = FILTER2_POOL()
  return wrap(make_gen(prev_gen, pred), prev_param, self.state)
end

local SCAN2_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, fn, init)
      local acc = init
      local function scan2_gen_%d(param, state)
        local k, v = prev_gen(param, state)
        if k == nil then return nil end
        acc = fn(acc, k, v)
        return k, acc
      end
      return scan2_gen_%d
    end
  ]], i, i)
end)

--[[
Running fold over (k, v) pairs; init required.
]]
function Seq:scan2(fn, init)
  if type(fn) ~= "function" then error("scan2: fn must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = SCAN2_POOL()
  return wrap(make_gen(prev_gen, fn, init), prev_param, self.state)
end

local CHAIN2_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(gen_a, param_a, gen_b, param_b, state_b0)
      local on_first = true
      local function chain2_gen_%d(param, state)
        if on_first then
          local k, v = gen_a(param_a, state)
          if k ~= nil then return k, v end
          on_first = false
          return chain2_gen_%d(param, state_b0)
        end
        return gen_b(param_b, state)
      end
      return chain2_gen_%d
    end
  ]], i, i, i)
end)

--[[
Yield every (k, v) pair of self, then every pair of other.
Both must be from the from_pairs family. Single-use.
]]
function Seq:chain2(other)
  assert(core.is_seq(other), "chain2: other must be a Seq")
  local gen_a, param_a = self.gen, self.param
  local gen_b, param_b = other.gen, other.param
  local make_gen = CHAIN2_POOL()
  return wrap(make_gen(gen_a, param_a, gen_b, param_b, other.state), nil, self.state)
end

--[[
Project down to a single-value Seq of just the values.
]]
function Seq:values()
  local prev_gen, prev_param = self.gen, self.param
  local function values_gen(param, state)
    local k, v = prev_gen(param, state)
    if k == nil then return nil end
    return k, v
  end
  return wrap(values_gen, prev_param, self.state)
end

--[[
Project down to a single-value Seq of just the keys.
]]
function Seq:keys()
  local prev_gen, prev_param = self.gen, self.param
  local function keys_gen(param, state)
    local k = prev_gen(param, state)
    if k == nil then return nil end
    return k, k
  end
  return wrap(keys_gen, prev_param, self.state)
end

return Seq