local D = require("datagen")
local Seq = require("seq")

local function drive(seq, fn)
  for k, v in seq.gen, seq.param, seq.state do fn(k, v) end
end

local function to_map(seq)
  local out = {}
  drive(seq, function(k, v) out[k] = v end)
  return out
end

describe("map2", function()
  it("transforms value, passes key through", function()
    local t = { a = 1, b = 2 }
    local r = to_map(Seq.from_pairs(t):map2(function(k, v) return v * 10 end))
    assert.same({ a = 10, b = 20 }, r)
  end)

  it("fn receives both key and value", function()
    local t = { x = 5 }
    local r = to_map(Seq.from_pairs(t):map2(function(k, v) return k .. "=" .. v end))
    assert.same({ x = "x=5" }, r)
  end)

  it("empty table yields empty", function()
    assert.equal(0, Seq.from_pairs({}):map2(function(k, v) return v end):values():length())
  end)

  it("on sparse mixed keys preserves all entries", function()
    local t = D.sparse_keyed(20)
    local expected_n = 0
    for _ in pairs(t) do expected_n = expected_n + 1 end
    local n = Seq.from_pairs(t):map2(function(k, v) return v end):values():length()
    assert.equal(expected_n, n)
  end)

  it("chained same-combinator long run (protopool rotation)", function()
    local seq = Seq.from_pairs({ a = 1 })
    for _ = 1, 60 do
      seq = seq:map2(function(k, v) return v + 1 end)
    end
    assert.equal(61, to_map(seq).a)
  end)

  it("rejects non-function fn", function()
    assert.has_error(function() Seq.from_pairs({ a = 1 }):map2(nil) end, "map2: fn must be a function")
  end)
end)

describe("filter2", function()
  it("keeps pairs matching predicate on value", function()
    local t = { a = 1, b = 2, c = 3, d = 4 }
    local r = to_map(Seq.from_pairs(t):filter2(function(k, v) return v % 2 == 0 end))
    assert.same({ b = 2, d = 4 }, r)
  end)

  it("predicate can inspect key", function()
    local t = { keep_a = 1, drop_b = 2 }
    local r = to_map(Seq.from_pairs(t):filter2(function(k, v) return k:match("^keep") end))
    assert.same({ keep_a = 1 }, r)
  end)

  it("always-false yields empty", function()
    assert.equal(0, Seq.from_pairs({ a = 1, b = 2 }):filter2(function() return false end):values():length())
  end)

  it("long run of consecutive rejects", function()
    local t = {}
    for i = 1, 20000 do t["k" .. i] = i end
    local n = Seq.from_pairs(t):filter2(function(k, v) return v == 20000 end):values():length()
    assert.equal(1, n)
  end)

  it("rejects non-function pred", function()
    assert.has_error(function() Seq.from_pairs({ a = 1 }):filter2(1) end, "filter2: pred must be a function")
  end)
end)

describe("scan2", function()
  it("running fold keeps key, threads accumulator as value", function()
    local t = { a = 1, b = 2, c = 3 }
    local last_acc = nil
    drive(Seq.from_pairs(t):scan2(function(acc, k, v) return acc + v end, 0), function(k, v)
      last_acc = v
    end)
    assert.equal(6, last_acc)
  end)

  it("fn receives accumulator, key, and value", function()
    local t = { only = 5 }
    local r = to_map(Seq.from_pairs(t):scan2(function(acc, k, v) return acc .. k .. v end, "init:"))
    assert.same({ only = "init:only5" }, r)
  end)

  it("empty table yields empty", function()
    assert.equal(0, Seq.from_pairs({}):scan2(function(acc, k, v) return acc end, 0):values():length())
  end)
end)

describe("chain2", function()
  it("concatenates two key/value sequences", function()
    local a = { x = 1 }
    local b = { y = 2 }
    local r = to_map(Seq.from_pairs(a):chain2(Seq.from_pairs(b)))
    assert.same({ x = 1, y = 2 }, r)
  end)

  it("first empty falls through to second", function()
    local r = to_map(Seq.from_pairs({}):chain2(Seq.from_pairs({ z = 9 })))
    assert.same({ z = 9 }, r)
  end)

  it("second empty yields only first", function()
    local r = to_map(Seq.from_pairs({ z = 9 }):chain2(Seq.from_pairs({})))
    assert.same({ z = 9 }, r)
  end)

  it("both empty yields empty", function()
    assert.equal(0, Seq.from_pairs({}):chain2(Seq.from_pairs({})):values():length())
  end)

  it("rejects non-Seq other", function()
    assert.has_error(function() Seq.from_pairs({ a = 1 }):chain2({ b = 2 }) end, "chain2: other must be a Seq")
  end)

  it("overlapping keys across sides both survive as separate pairs", function()
    local n = Seq.from_pairs({ dup = 1 }):chain2(Seq.from_pairs({ dup = 2 })):values():length()
    assert.equal(2, n)
  end)
end)

describe("keys / values", function()
  it("values: projects to single-value Seq", function()
    local t = { a = 1, b = 2, c = 3 }
    local sum = Seq.from_pairs(t):values():reduce(function(acc, v) return acc + v end, 0)
    assert.equal(6, sum)
  end)

  it("keys: projects to single-value Seq of keys", function()
    local t = { a = 1, b = 2 }
    local n = 0
    Seq.from_pairs(t):keys():each(function(k)
      n = n + 1
      assert.is_true(k == "a" or k == "b")
    end)
    assert.equal(2, n)
  end)

  it("values: chains into map/filter/take like any single-value Seq", function()
    local t = { a = 1, b = 2, c = 3, d = 4 }
    local r = Seq.from_pairs(t):values():filter(function(v) return v > 1 end):collect()
    table.sort(r)
    assert.same({ 2, 3, 4 }, r)
  end)

  it("keys: chains into map/filter/take like any single-value Seq", function()
    local t = { aa = 1, bb = 2, cc = 3 }
    local r = Seq.from_pairs(t):keys():map(function(k) return #k end):collect()
    assert.same({ 2, 2, 2 }, r)
  end)

  it("values: on empty table", function()
    assert.equal(0, Seq.from_pairs({}):values():length())
  end)

  it("keys: on empty table", function()
    assert.equal(0, Seq.from_pairs({}):keys():length())
  end)

  it("values: preserves complex nested-table values by reference", function()
    local inner = { 1, 2, 3 }
    local t = { a = inner }
    local r = Seq.from_pairs(t):values():collect()
    assert.equal(inner, r[1])
  end)
end)

describe("combined family stress", function()
  it("map2 -> filter2 -> values chain on nested-record-derived table", function()
    local records = D.nested_records(30)
    local by_id = {}
    for _, r in ipairs(records) do by_id[r.id] = r.score end
    local high_scores = Seq.from_pairs(by_id)
      :filter2(function(k, v) return v > 0 end)
      :map2(function(k, v) return v * 2 end)
      :values()
      :collect()
    for _, v in ipairs(high_scores) do assert.is_true(v > 0) end
  end)
end)
