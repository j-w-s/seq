--[[
Sources for producing the initial triplet for the sequence.
]]

local core = require("core")
local wrap = core.wrap
local Seq = core.Seq

--[[
Single-value sequence over an array.
]]
function Seq.from(t)
  local gen, param, state = ipairs(t)
  return wrap(gen, param, state)
end

--[[
Key-value sequence over a table.
]]
function Seq.from_pairs(t)
  local gen, param, state = pairs(t)
  return wrap(gen, param, state)
end

--[[
Range sequence with optional step, default step = 1.
]]
function Seq.range(from, to, step)
  local step_val = step or 1
  assert(step_val ~= 0, "Seq.range: step must not be 0")
  local function range_gen(_, i)
    i = i + step_val
    if (step_val > 0 and i > to) or (step_val < 0 and i < to) then return nil end
    return i, i
  end
  return wrap(range_gen, nil, from - step_val)
end

--[[
Repeat a value n times, or forever if n is omitted.
If infinite, use with a terminal operation before draining.
--]]
function Seq.repeat_(v, n)
  if n == nil then
    local function repeat_gen(_, _state)
      return true, v
    end
    return wrap(repeat_gen, nil, true)
  end
  assert(type(n) == "number" and n >= 0, "Seq.repeat_: n must be a non-negative number")
  local function repeat_gen(_, i)
    i = i + 1
    if i > n then return nil end
    return i, v
  end
  return wrap(repeat_gen, nil, 0)
end

return Seq