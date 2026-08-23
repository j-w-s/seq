--[[
The single-value combinator family. Each gen closure is built from a
pool of prototype variants; see protopool.lua.
]]

local core = require("core")
local protopool = require("protopool")
local wrap = core.wrap
local Seq = core.Seq

local POOL_SIZE = protopool.DEFAULT_POOL_SIZE

local MAP_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, fn)
      local function map_gen_%d(param, state)
        local new_state, v = prev_gen(param, state)
        if new_state == nil then return nil end
        return new_state, fn(v)
      end
      return map_gen_%d
    end
  ]], i, i)
end)

--[[
Transform each element through fn(v).
]]
function Seq:map(fn)
  if type(fn) ~= "function" then error("map: fn must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = MAP_POOL()
  return wrap(make_gen(prev_gen, fn), prev_param, self.state)
end

local FILTER_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, pred)
      local filter_gen_%d
      filter_gen_%d = function(param, state)
        local new_state, v = prev_gen(param, state)
        if new_state == nil then return nil end
        if pred(v) then return new_state, v end
        return filter_gen_%d(param, new_state)
      end
      return filter_gen_%d
    end
  ]], i, i, i, i)
end)

--[[
Keep only elements where pred(v) is true.
]]
function Seq:filter(pred)
  if type(pred) ~= "function" then error("filter: pred must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = FILTER_POOL()
  return wrap(make_gen(prev_gen, pred), prev_param, self.state)
end

local TAKE_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, n)
      local remaining = n
      local function take_gen_%d(param, state)
        if remaining <= 0 then return nil end
        local new_state, va, vb = prev_gen(param, state)
        if new_state == nil then return nil end
        remaining = remaining - 1
        return new_state, va, vb
      end
      return take_gen_%d
    end
  ]], i, i)
end)

--[[
Yield at most the first n elements.
]]
function Seq:take(n)
  if not (type(n) == "number" and n >= 0) then error("take: n must be a non-negative number", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = TAKE_POOL()
  return wrap(make_gen(prev_gen, n), prev_param, self.state)
end

local TAKE_WHILE_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, pred)
      local stopped = false
      local function take_while_gen_%d(param, state)
        if stopped then return nil end
        local new_state, v = prev_gen(param, state)
        if new_state == nil then return nil end
        if not pred(v) then
          stopped = true
          return nil
        end
        return new_state, v
      end
      return take_while_gen_%d
    end
  ]], i, i)
end)

--[[
Yield elements until pred(v) first fails.
]]
function Seq:take_while(pred)
  if type(pred) ~= "function" then error("take_while: pred must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = TAKE_WHILE_POOL()
  return wrap(make_gen(prev_gen, pred), prev_param, self.state)
end

local DROP_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, n)
      local to_skip = n
      local drop_gen_%d
      drop_gen_%d = function(param, state)
        local new_state, v = prev_gen(param, state)
        if new_state == nil then return nil end
        if to_skip <= 0 then return new_state, v end
        to_skip = to_skip - 1
        return drop_gen_%d(param, new_state)
      end
      return drop_gen_%d
    end
  ]], i, i, i, i)
end)

--[[
Skip the first n elements, then yield the rest.
]]
function Seq:drop(n)
  if not (type(n) == "number" and n >= 0) then error("drop: n must be a non-negative number", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = DROP_POOL()
  return wrap(make_gen(prev_gen, n), prev_param, self.state)
end

local DROP_WHILE_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, pred)
      local dropping = true
      local drop_while_gen_%d
      drop_while_gen_%d = function(param, state)
        local new_state, v = prev_gen(param, state)
        if new_state == nil then return nil end
        if not dropping then return new_state, v end
        if pred(v) then return drop_while_gen_%d(param, new_state) end
        dropping = false
        return new_state, v
      end
      return drop_while_gen_%d
    end
  ]], i, i, i, i)
end)

--[[
Skip elements while pred(v) holds, then yield the rest.
]]
function Seq:drop_while(pred)
  if type(pred) ~= "function" then error("drop_while: pred must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = DROP_WHILE_POOL()
  return wrap(make_gen(prev_gen, pred), prev_param, self.state)
end

local SCAN_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, fn, init)
      local acc = init
      local function scan_gen_%d(param, state)
        local new_state, v = prev_gen(param, state)
        if new_state == nil then return nil end
        acc = fn(acc, v)
        return new_state, acc
      end
      return scan_gen_%d
    end
  ]], i, i)
end)

--[[
Running fold; init is required, same as reduce().
]]
function Seq:scan(fn, init)
  if type(fn) ~= "function" then error("scan: fn must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = SCAN_POOL()
  return wrap(make_gen(prev_gen, fn, init), prev_param, self.state)
end

local CHAIN_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(gen_a, param_a, gen_b, param_b, state_b0)
      local on_first = true
      local function chain_gen_%d(param, state)
        if on_first then
          local new_a, va, vb = gen_a(param_a, state)
          if new_a ~= nil then return new_a, va, vb end
          on_first = false
          return chain_gen_%d(param, state_b0)
        end
        return gen_b(param_b, state)
      end
      return chain_gen_%d
    end
  ]], i, i, i)
end)

--[[
Yield every element of self, then every element of other. Single-use.
]]
function Seq:chain(other)
  assert(core.is_seq(other), "chain: other must be a Seq")
  local gen_a, param_a = self.gen, self.param
  local gen_b, param_b = other.gen, other.param
  local make_gen = CHAIN_POOL()
  return wrap(make_gen(gen_a, param_a, gen_b, param_b, other.state), nil, self.state)
end

local ENUMERATE_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen)
      local idx = 0
      local function enumerate_gen_%d(param, state)
        local new_state, v = prev_gen(param, state)
        if new_state == nil then return nil end
        idx = idx + 1
        return new_state, idx, v
      end
      return enumerate_gen_%d
    end
  ]], i, i)
end)

--[[
Yields (index, value) pairs, index starting at 1.
]]
function Seq:enumerate()
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = ENUMERATE_POOL()
  return wrap(make_gen(prev_gen), prev_param, self.state)
end

local ZIP_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(gen_a, param_a, gen_b, param_b, state_a0, state_b0)
      local state_a, state_b = state_a0, state_b0
      local function zip_gen_%d(param, state)
        local new_a, va = gen_a(param_a, state_a)
        if new_a == nil then return nil end
        local new_b, vb = gen_b(param_b, state_b)
        if new_b == nil then return nil end
        state_a, state_b = new_a, new_b
        return state, va, vb
      end
      return zip_gen_%d
    end
  ]], i, i)
end)

--[[
Yields (a, b) pairs, stopping when either side ends.
]]
function Seq:zip(other)
  assert(core.is_seq(other), "zip: other must be a Seq")
  local gen_a, param_a = self.gen, self.param
  local gen_b, param_b = other.gen, other.param
  local make_gen = ZIP_POOL()
  return wrap(make_gen(gen_a, param_a, gen_b, param_b, self.state, other.state), nil, true)
end

local FLAT_MAP_POOL = protopool.new_pool(POOL_SIZE, function(i)
  return string.format([[
    return function(prev_gen, fn, is_seq_fn, outer_state0)
      local function make_inner(v)
        local inner = fn(v)
        if is_seq_fn(inner) then
          return inner.gen, inner.param, inner.state
        end
        return ipairs(inner)
      end

      local outer_state, inner_gen, inner_param, inner_state = outer_state0, nil, nil, nil

      local flat_map_gen_%d
      flat_map_gen_%d = function(param, state)
        if inner_gen ~= nil then
          local new_inner_state, v = inner_gen(inner_param, inner_state)
          if new_inner_state ~= nil then
            inner_state = new_inner_state
            return new_inner_state, v
          end
        end
        local new_outer, ov = prev_gen(param, outer_state)
        if new_outer == nil then return nil end
        outer_state = new_outer
        inner_gen, inner_param, inner_state = make_inner(ov)
        return flat_map_gen_%d(param, state)
      end
      return flat_map_gen_%d
    end
  ]], i, i, i, i)
end)

--[[
fn(v) must return a Seq or plain array table. Avoid functions that build
a fresh closure per call. FNEW NYI in LuaJIT.
]]
function Seq:flat_map(fn)
  if type(fn) ~= "function" then error("flat_map: fn must be a function", 2) end
  local prev_gen, prev_param = self.gen, self.param
  local make_gen = FLAT_MAP_POOL()
  return wrap(make_gen(prev_gen, fn, core.is_seq, self.state), prev_param, true)
end

return Seq