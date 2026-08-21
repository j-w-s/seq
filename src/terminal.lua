--[[
Terminal operations for consuming a sequence.
]]

local core = require("core")
local new_tab = require("table.new")
local Seq = core.Seq

--[[
Collect a single-value sequence into an array table.
size_hint pre-allocates.
]]
function Seq:collect(size_hint)
  local result, n
  if size_hint then
    result, n = new_tab(size_hint, 0), 0
  else
    result, n = {}, 0
  end
  for _, v in self.gen, self.param, self.state do
    n = n + 1
    assert(v ~= nil, "collect: sequence produced a nil element at position "
      .. n .. ". Seq does not support nil elements; use a sentinel value instead")
    result[n] = v
  end
  return result
end

--[[
Collect a zip()/enumerate() sequence into an array of { a, b } pairs.
size_hint pre-allocates.
]]
function Seq:collect2(size_hint)
  local result, n
  if size_hint then
    result, n = new_tab(size_hint, 0), 0
  else
    result, n = {}, 0
  end
  for _, a, b in self.gen, self.param, self.state do
    n = n + 1
    assert(a ~= nil, "collect2: sequence produced a nil first value at position "
      .. n .. ". Seq does not support nil elements; use a sentinel value instead")
    result[n] = { a, b }
  end
  return result
end

--[[
Collect a from_pairs-family sequence into an array of { k, v } pairs.
size_hint pre-allocates.
]]
function Seq:collect_pairs(size_hint)
  local result, n
  if size_hint then
    result, n = new_tab(size_hint, 0), 0
  else
    result, n = {}, 0
  end
  for k, v in self.gen, self.param, self.state do
    n = n + 1
    assert(k ~= nil, "collect_pairs: sequence produced a nil key at position "
      .. n .. ". Seq does not support nil elements; use a sentinel value instead")
    result[n] = { k, v }
  end
  return result
end

--[[
Fold fn(acc, v) over every element. init is required.
]]
function Seq:reduce(fn, init)
  assert(type(fn) == "function", "reduce: fn must be a function")
  local acc = init
  for _, v in self.gen, self.param, self.state do
    acc = fn(acc, v)
  end
  return acc
end

--[[
Call fn(v) for every element, discarding the result.
]]
function Seq:each(fn)
  assert(type(fn) == "function", "Seq.each: fn must be a function")
  for _, v in self.gen, self.param, self.state do
    fn(v)
  end
end

--[[
Count the elements in the sequence.
]]
function Seq:length()
  local n = 0
  for _ in self.gen, self.param, self.state do
    n = n + 1
  end
  return n
end

--[[
Return the first element for which pred(v) is true, or nil if none match.
]]
function Seq:find(pred)
  assert(type(pred) == "function", "find: pred must be a function")
  for _, v in self.gen, self.param, self.state do
    if pred(v) then return v end
  end
  return nil
end

--[[
True if pred(v) holds for at least one element.
]]
function Seq:any(pred)
  assert(type(pred) == "function", "any: pred must be a function")
  for _, v in self.gen, self.param, self.state do
    if pred(v) then return true end
  end
  return false
end

--[[
True if pred(v) holds for every element or the sequence is empty.
]]
function Seq:all(pred)
  assert(type(pred) == "function", "all: pred must be a function")
  for _, v in self.gen, self.param, self.state do
    if not pred(v) then return false end
  end
  return true
end

return Seq