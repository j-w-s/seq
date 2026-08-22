--[[
Every combinator constructor's captured locals (prev_gen/prev_param/fn/
pred/n/...) must be assigned exactly once so LuaJIT tags the upvalue
PROTO_UV_IMMUTABLE.
]]

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then return nil, err end
  local content = f:read("*a")
  f:close()
  return content
end

--[[
Extract top-level `function Seq:name(...) ... end` / `function
Seq.name(...) ... end` blocks by balanced function/end counting.
]]
local function extract_methods(src)
  local methods = {}
  local line = 1
  local i = 1
  local len = #src
  while i <= len do
    local s, e, name, params = src:find("function%s+Seq[:%.]([%a_][%w_]*)%s*%(([^%)]*)%)", i)
    if not s then break end
    for _ in src:sub(i, s):gmatch("\n") do line = line + 1 end
    local start_line = line
    local pos = e + 1
    local depth = 1
    local body_start = pos
    while depth > 0 and pos <= len do
      local kw_s, kw_e, kw = src:find("([%a_][%w_]*)", pos)
      if not kw_s then break end
      if kw == "function" or kw == "do" or kw == "repeat" then
        depth = depth + 1
      elseif kw == "if" or kw == "for" or kw == "while" then
        depth = depth + 1
      elseif kw == "end" or kw == "until" then
        depth = depth - 1
      end
      pos = kw_e + 1
    end
    local body = src:sub(body_start, pos - 1)
    methods[#methods + 1] = {
      name = name,
      params_str = params,
      body = body,
      line = start_line,
    }
    line = start_line
    for _ in src:sub(i, pos - 1):gmatch("\n") do line = line + 1 end
    i = pos
  end
  return methods
end

--[[
Candidate captured upvalues: self.gen/self.param captures and the method's own declared params.
]]
local function find_candidates(body, params_str)
  local candidates = {}

  for lhs in body:gmatch("local%s+([%w_,%s]-)%s*=%s*self%.[%w_]+") do
    for name in lhs:gmatch("[%a_][%w_]*") do
      candidates[name] = true
    end
  end

  for name in params_str:gmatch("[%a_][%w_]*") do
    if name ~= "self" then
      candidates[name] = true
    end
  end

  return candidates
end

--[[
True if name is ever the target of a plain assignment in body, excluding
its own `local name = ...` declaration.
]]
local function is_reassigned(body, name)
  local scrubbed = body:gsub("local%s+[%w_,%s]-" .. name .. "[%w_,%s]-%s*=", "")

  for pos, tok in scrubbed:gmatch("()([%a_][%w_]*)") do
    if tok == name then
      local rest = scrubbed:sub(pos + #name)
      local j = 1
      while true do
        local _, after_ws = rest:sub(j):match("^(%s*)()")
        j = j + (after_ws - 1)
        if rest:sub(j, j) == "," then
          local nxt = rest:sub(j + 1):match("^%s*([%a_][%w_]*)")
          if nxt then
            j = j + 1 + #(rest:sub(j + 1):match("^%s*") or "") + #nxt
          else
            break
          end
        else
          break
        end
      end
      local after = rest:sub(j)
      if after:match("^%s*=") and not after:match("^%s*==") then
        return true
      end
    end
  end
  return false
end

local function check_file(path)
  local src, err = read_file(path)
  if not src then
    io.stderr:write("cannot read " .. path .. ": " .. tostring(err) .. "\n")
    return {}
  end
  local violations = {}
  local methods = extract_methods(src)
  for _, m in ipairs(methods) do
    local candidates = find_candidates(m.body, m.params_str)
    for name in pairs(candidates) do
      if is_reassigned(m.body, name) then
        violations[#violations + 1] = {
          file = path,
          method = m.name,
          line = m.line,
          var = name,
        }
      end
    end
  end
  return violations
end

local function main(argv)
  local files = argv
  if #files == 0 then
    files = {
      "src/combinators.lua",
      "src/combinators_pairs.lua",
    }
  end

  local all_violations = {}
  for _, f in ipairs(files) do
    local vs = check_file(f)
    for _, v in ipairs(vs) do all_violations[#all_violations + 1] = v end
  end

  if #all_violations == 0 then
    print(("check_upvalue: OK; scanned %d file(s), no reassigned captures found."):format(#files))
    os.exit(0)
  else
    print(("check_upvalue: FOUND %d VIOLATION(S):"):format(#all_violations))
    for _, v in ipairs(all_violations) do
      print(("  %s:%d in Seq:%s; captured upvalue '%s' appears to be reassigned")
        :format(v.file, v.line, v.method, v.var))
    end
    print("\ncaptured locals (prev_gen/prev_param/callback) must be assigned exactly")
    print("once so the parser tags the corresponding upvalue PROTO_UV_IMMUTABLE.")
    os.exit(1)
  end
end

main({ ... })
