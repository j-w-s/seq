--[[
Wrapper table for the lazy sequence's gen/param/state iterator triplet.
]]

if type(jit) ~= "table" or type(jit.version) ~= "string" then
    error("seq requires LuaJIT", 0)
end

local M = {}

local Seq = {}
Seq.__index = Seq
M.Seq = Seq

function M.wrap(gen, param, state)
  return setmetatable({ gen = gen, param = param, state = state }, Seq)
end

function M.is_seq(v)
    return type(v) == "table" and getmetatable(v) == Seq
end

return M