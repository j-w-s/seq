--[[
Pooling moves the gen closure one level deeper, into
a Lua source string built by string.format and load() at
pool-construction time. check_upvalue.lua checks the outer
method never reassigns prev_gen/prev_param/fn before make_gen();
this checks the inner generated constructor has the same property
for the nested gen closure that captures them as upvalues.
]]

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then return nil, err end
  local content = f:read("*a")
  f:close()
  return content
end

local function extract_templates(src)
  local templates = {}
  for pool_name, body in
    src:gmatch("local%s+([%u%d_]+)%s*=%s*protopool%.new_pool%s*%([^,]+,%s*"
      .. "function%s*%(i%)%s*(.-)%s*end%s*%)%s*\n") do
    local template_src = body:match("string%.format%(%[%[(.-)%]%],")
    if template_src then
      templates[#templates + 1] = { pool_name = pool_name, template = template_src }
    end
  end
  return templates
end

local function materialize(template_src)
  return template_src:gsub("%%d", "1")
end

--[[
Candidate captured upvalues in a materialized template: outermost
function's params and any self-recursive binding (`local X; X =
function ... end`, used by filter/drop/chain/etc).
]]
local function find_candidates(src)
  local candidates = {}
  local params_str = src:match("function%s*%(([^%)]*)%)")
  if params_str then
    for name in params_str:gmatch("[%a_][%w_]*") do
      candidates[name] = true
    end
  end
  for name in src:gmatch("local%s+([%a_][%w_]*)\n%s*[%a_][%w_]*%s*=%s*function") do
    candidates[name] = true
  end
  for name in src:gmatch("local%s+([%a_][%w_]*)%s*\n%s*%1%s*=%s*function") do
    candidates[name] = true
  end
  return candidates
end

local function is_reassigned(body, name)
  local scrubbed = body:gsub("local%s+[%w_,%s]-" .. name .. "[%w_,%s]-%s*=", "")
  for pos, tok in scrubbed:gmatch("()([%a_][%w_]*)") do
    if tok == name then
      local rest = scrubbed:sub(pos + #name)
      local after = rest:match("^(%s*=?=?)")
      if rest:match("^%s*=") and not rest:match("^%s*==") then
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
  local templates = extract_templates(src)

  for _, t in ipairs(templates) do
    local materialized = materialize(t.template)
    local chunk, load_err = load(materialized, "=" .. t.pool_name .. "_variant_1")
    if not chunk then
      violations[#violations + 1] = {
        file = path,
        pool = t.pool_name,
        kind = "SYNTAX ERROR in template",
        detail = tostring(load_err),
      }
    else
      local candidates = find_candidates(materialized)
      for name in pairs(candidates) do
        if is_reassigned(materialized, name) then
          violations[#violations + 1] = {
            file = path,
            pool = t.pool_name,
            kind = "reassigned captured parameter",
            detail = name,
          }
        end
      end
    end
  end

  return violations, #templates
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
  local total_templates = 0
  for _, f in ipairs(files) do
    local vs, n = check_file(f)
    total_templates = total_templates + (n or 0)
    for _, v in ipairs(vs) do all_violations[#all_violations + 1] = v end
  end

  if #all_violations == 0 then
    print(("check_pool_discipline: OK; scanned %d pool template(s) across %d file(s), all clean.")
      :format(total_templates, #files))
    os.exit(0)
  else
    print(("check_pool_discipline: FOUND %d VIOLATION(S):"):format(#all_violations))
    for _, v in ipairs(all_violations) do
      print(("  %s [%s]: %s -- %s"):format(v.file, v.pool, v.kind, v.detail))
    end
    os.exit(1)
  end
end

main({ ... })
