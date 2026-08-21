local D = require("datagen")
local Seq = require("seq")

describe("collect", function()
  it("builds array in order", function()
    assert.same({ 3, 1, 4, 1, 5 }, Seq.from({ 3, 1, 4, 1, 5 }):collect())
  end)

  it("empty source yields empty array", function()
    assert.same({}, Seq.from({}):collect())
  end)

  it("rejects nil elements produced mid-sequence", function()
    local seq = Seq.from({ 1, 2, 3 }):map(function(x)
      if x == 2 then return nil end
      return x
    end)
    local ok, err = pcall(function() seq:collect() end)
    assert.is_false(ok)
    assert.matches("does not support nil elements", err)
  end)

  it("error message reports 1-based position of nil", function()
    local seq = Seq.from({ 1, 2, 3 }):map(function(x)
      if x == 3 then return nil end
      return x
    end)
    local ok, err = pcall(function() seq:collect() end)
    assert.is_false(ok)
    assert.matches("position 3", err)
  end)

  it("false is a valid element, not treated as nil", function()
    assert.same({ true, false, true }, Seq.from({ true, false, true }):collect())
  end)

  it("large source collects fully and in order", function()
    local t = D.sequential_ints(100000)
    assert.same(t, Seq.from(t):collect())
  end)

  it("size_hint produces the same result as no hint", function()
    local t = D.sequential_ints(50)
    local expected = Seq.from(t):map(function(x) return x * 2 end):collect()
    assert.same(expected, Seq.from(t):map(function(x) return x * 2 end):collect(50))
  end)

  it("undersized size_hint still produces a correct, full-length result", function()
    local t = D.sequential_ints(50)
    local expected = Seq.from(t):map(function(x) return x * 2 end):collect()
    assert.same(expected, Seq.from(t):map(function(x) return x * 2 end):collect(1))
  end)

  it("oversized size_hint still produces a correct result", function()
    local t = D.sequential_ints(50)
    local expected = Seq.from(t):collect()
    assert.same(expected, Seq.from(t):collect(1000))
  end)

  it("size_hint on an empty source yields empty array", function()
    assert.same({}, Seq.from({}):collect(100))
  end)
end)

describe("collect2", function()
  it("pairs up zip() output in order", function()
    local r = Seq.from({ 1, 2, 3 }):zip(Seq.from({ "a", "b", "c" })):collect2()
    assert.same({ { 1, "a" }, { 2, "b" }, { 3, "c" } }, r)
  end)

  it("pairs up enumerate() output in order", function()
    local r = Seq.from({ "x", "y" }):enumerate():collect2()
    assert.same({ { 1, "x" }, { 2, "y" } }, r)
  end)

  it("empty source yields empty array", function()
    assert.same({}, Seq.from({}):zip(Seq.from({})):collect2())
  end)

  it("stops at the shorter side of an uneven zip", function()
    local r = Seq.from({ 1, 2, 3, 4 }):zip(Seq.from({ "a", "b" })):collect2()
    assert.same({ { 1, "a" }, { 2, "b" } }, r)
  end)

  it("size_hint produces the same result as no hint", function()
    local expected = Seq.from({ 1, 2 }):zip(Seq.from({ 3, 4 })):collect2()
    assert.same(expected, Seq.from({ 1, 2 }):zip(Seq.from({ 3, 4 })):collect2(2))
  end)

  it("rejects a nil first value", function()
    local a = Seq.from({ 1, 2, 3 }):map(function(x)
      if x == 2 then return nil end
      return x
    end)
    local b = Seq.from({ 10, 20, 30 })
    local ok, err = pcall(function() a:zip(b):collect2() end)
    assert.is_false(ok)
    assert.matches("does not support nil elements", err)
  end)
end)

describe("collect_pairs", function()
  it("pairs up from_pairs() output", function()
    local t = { x = 1, y = 2 }
    local r = Seq.from_pairs(t):collect_pairs()
    local seen = {}
    for _, pair in ipairs(r) do seen[pair[1]] = pair[2] end
    assert.same({ x = 1, y = 2 }, seen)
    assert.equal(2, #r)
  end)

  it("reflects map2's transformed values", function()
    local t = { x = 1, y = 2 }
    local r = Seq.from_pairs(t):map2(function(k, v) return v * 10 end):collect_pairs()
    local seen = {}
    for _, pair in ipairs(r) do seen[pair[1]] = pair[2] end
    assert.same({ x = 10, y = 20 }, seen)
  end)

  it("empty source yields empty array", function()
    assert.same({}, Seq.from_pairs({}):collect_pairs())
  end)

  it("size_hint produces the same result as no hint", function()
    local t = { x = 1 }
    local expected = Seq.from_pairs(t):collect_pairs()
    assert.same(expected, Seq.from_pairs(t):collect_pairs(1))
  end)
end)

describe("reduce", function()
  it("sums with explicit init", function()
    assert.equal(10, Seq.from({ 1, 2, 3, 4 }):reduce(function(a, v) return a + v end, 0))
  end)

  it("empty source returns init unchanged", function()
    assert.equal(42, Seq.from({}):reduce(function(a, v) return a + v end, 42))
  end)

  it("init can be any type (string concat)", function()
    assert.equal("abc", Seq.from({ "b", "c" }):reduce(function(a, v) return a .. v end, "a"))
  end)

  it("init can be a table, mutated across the fold", function()
    local r = Seq.from({ 1, 2, 3 }):reduce(function(acc, v)
      acc[#acc + 1] = v * v
      return acc
    end, {})
    assert.same({ 1, 4, 9 }, r)
  end)

  it("rejects non-function fn", function()
    assert.has_error(function() Seq.from({ 1 }):reduce(nil, 0) end, "reduce: fn must be a function")
  end)

  it("single element short-circuits to fn(init, v)", function()
    assert.equal(10, Seq.from({ 5 }):reduce(function(a, v) return a * v end, 2))
  end)
end)

describe("each", function()
  it("visits every element exactly once, in order", function()
    local seen = {}
    Seq.from({ 10, 20, 30 }):each(function(v) seen[#seen + 1] = v end)
    assert.same({ 10, 20, 30 }, seen)
  end)

  it("on empty source never calls fn", function()
    local calls = 0
    Seq.from({}):each(function() calls = calls + 1 end)
    assert.equal(0, calls)
  end)

  it("only forwards single value even from 2-value gens", function()
    local seen = {}
    Seq.from({ "a", "b" }):enumerate():each(function(x) seen[#seen + 1] = x end)
    assert.same({ 1, 2 }, seen)
  end)

  it("rejects non-function fn", function()
    assert.has_error(function() Seq.from({ 1 }):each("x") end, "Seq.each: fn must be a function")
  end)

  it("side effects observed on nested record data", function()
    local t = D.nested_records(15)
    local active_count = 0
    Seq.from(t):each(function(r) if r.active then active_count = active_count + 1 end end)
    local expected = 0
    for _, r in ipairs(t) do if r.active then expected = expected + 1 end end
    assert.equal(expected, active_count)
  end)
end)

describe("length", function()
  it("counts elements", function()
    assert.equal(5, Seq.from({ 1, 2, 3, 4, 5 }):length())
  end)

  it("empty source is zero", function()
    assert.equal(0, Seq.from({}):length())
  end)

  it("unaffected by element values (works on falsy elements)", function()
    assert.equal(3, Seq.from({ false, false, false }):length())
  end)

  it("after filter reflects post-filter count", function()
    assert.equal(333, Seq.from(D.sequential_ints(1000)):filter(function(x) return x % 3 == 0 end):length())
  end)

  it("same for both from() and from_pairs()-derived values()", function()
    local t = { a = 1, b = 2, c = 3 }
    assert.equal(3, Seq.from_pairs(t):values():length())
  end)
end)

describe("find", function()
  it("returns first match", function()
    assert.equal(4, Seq.from({ 1, 3, 5, 4, 7 }):find(function(x) return x % 2 == 0 end))
  end)

  it("returns nil when no match", function()
    assert.is_nil(Seq.from({ 1, 3, 5 }):find(function(x) return x % 2 == 0 end))
  end)

  it("on empty source returns nil", function()
    assert.is_nil(Seq.from({}):find(function() return true end))
  end)

  it("short-circuits (does not evaluate pred past first match)", function()
    local calls = 0
    local r = Seq.from({ 1, 2, 3, 4, 5 }):find(function(x)
      calls = calls + 1
      return x == 2
    end)
    assert.equal(2, r)
    assert.equal(2, calls)
  end)

  it("rejects non-function pred", function()
    assert.has_error(function() Seq.from({ 1 }):find(nil) end, "find: pred must be a function")
  end)

  it("matches falsy-but-not-nil element (false)", function()
    assert.is_false(Seq.from({ 1, 2, false, 3 }):find(function(x) return x == false end))
  end)
end)

describe("any", function()
  it("true when at least one matches", function()
    assert.is_true(Seq.from({ 1, 2, 3 }):any(function(x) return x == 2 end))
  end)

  it("false when none match", function()
    assert.is_false(Seq.from({ 1, 2, 3 }):any(function(x) return x > 10 end))
  end)

  it("false on empty source (vacuous)", function()
    assert.is_false(Seq.from({}):any(function() return true end))
  end)

  it("short-circuits on first true", function()
    local calls = 0
    Seq.from(D.sequential_ints(100000)):any(function(x)
      calls = calls + 1
      return x == 1
    end)
    assert.equal(1, calls)
  end)

  it("rejects non-function pred", function()
    assert.has_error(function() Seq.from({ 1 }):any(nil) end, "any: pred must be a function")
  end)
end)

describe("all", function()
  it("true when every element matches", function()
    assert.is_true(Seq.from({ 2, 4, 6 }):all(function(x) return x % 2 == 0 end))
  end)

  it("false when at least one fails", function()
    assert.is_false(Seq.from({ 2, 4, 5 }):all(function(x) return x % 2 == 0 end))
  end)

  it("true on empty source (vacuous truth)", function()
    assert.is_true(Seq.from({}):all(function() return false end))
  end)

  it("short-circuits on first false", function()
    local calls = 0
    Seq.from(D.sequential_ints(100000)):all(function(x)
      calls = calls + 1
      return x < 3
    end)
    assert.equal(3, calls)
  end)

  it("rejects non-function pred", function()
    assert.has_error(function() Seq.from({ 1 }):all(nil) end, "all: pred must be a function")
  end)
end)

describe("combined terminal stress", function()
  it("reduce building a frequency table over repeating-cycle data", function()
    local t = D.repeating_ints(700)
    local freq = Seq.from(t):reduce(function(acc, v)
      acc[v] = (acc[v] or 0) + 1
      return acc
    end, {})
    local total = 0
    for _, c in pairs(freq) do total = total + c end
    assert.equal(700, total)
  end)

  it("all + any agree with manual scan over tabular rows", function()
    local rows = D.tabular_rows(500)
    local any_empty_note = Seq.from(rows):any(function(r) return r.note == "" end)
    local all_have_dept = Seq.from(rows):all(function(r) return r.dept ~= nil end)
    assert.is_true(any_empty_note)
    assert.is_true(all_have_dept)
  end)
end)
