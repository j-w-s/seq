--[[
Simple data generator for testing.
]]

local M = {}

local seed = 20260818
local huge = math.huge

local NONE = setmetatable({}, { __tostring = function() return "<none>" end })
M.NONE = NONE

--[[
Setting a specific seed so the data is deterministic, hard to test otherwise.
]]
math.randomseed(seed)

--[[
Integers from 'from' to 'from + n - 1', default from = 1.
]]
function M.sequential_ints(n, from)
  from = from or 1
  local t = {}
  for i = 1, n do t[i] = from + i - 1 end
  return t
end

function M.mixed_scalars()
  return {
    0, -0.0, 1, -1, 0.5, -0.5,
    huge, -huge,
    2 ^ 53, -2 ^ 53,
    1e300, 1e-300,
    "", "a", "the quick brown fox",
    true, false,
    {}, { 1, 2, 3 },
  }
end

function M.nested_records(n)
  local tags_pool = { "a", "b", "c", "d", "e" }
  local t = {}
  for i = 1, n do
    local has_email = i % 3 ~= 0
    local ntags = i % 4
    local tags = {}
    for j = 1, ntags do tags[j] = tags_pool[((i + j) % #tags_pool) + 1] end
    t[i] = {
      id = i,
      name = "user_" .. i,
      email = has_email and ("user" .. i .. "@example.com") or NONE,
      active = i % 2 == 0,
      score = (i * 37) % 101 - 50,
      tags = tags,
      meta = { created = 1000 + i, depth = i % 5 },
    }
  end
  return t
end

function M.sparse_keyed(n)
  local t = {}
  for i = 1, n do
    if i % 3 == 0 then
      t["key_" .. i] = i * 2
    elseif i % 3 == 1 then
      t[i * 100] = i * 2
    else
      t[-i] = i * 2
    end
  end
  t[0] = 999
  return t
end

function M.unicode_strings()
  return {
    "hello",
    "héllo",
    "日本語",
    "AI slop 🎉🔥",
    "\t\n\r",
    string.rep("x", 500),
    "",
    "null\0byte",
  }
end

function M.repeating_ints(n)
  local t = {}
  for i = 1, n do t[i] = i % 7 end
  return t
end

function M.tabular_rows(n)
  local depts = { "engineering", "sales", "legal", "marketing", "it", "operations" }
  local t = {}
  for i = 1, n do
    t[i] = {
      id = i,
      first_name = "First" .. i,
      last_name = "Last" .. i,
      dept = depts[(i % #depts) + 1],
      salary = 40000 + (i * 137) % 60000,
      note = (i % 5 == 0) and "" or ("note-" .. i),
    }
  end
  return t
end

function M.uniform_floats(n)
  local t = {}
  for i = 1, n do t[i] = math.random() * 2 - 1 end
  return t
end

function M.deep_array(depth, leaf)
  local t = { leaf or "leaf" }
  for _ = 1, depth do t = { t } end
  return t
end

return M