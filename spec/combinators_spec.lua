local D = require("datagen")
local Seq = require("seq")

local function drive(seq, fn)
  for _, a, b in seq.gen, seq.param, seq.state do fn(a, b) end
end

describe("map", function()
  it("doubles values", function()
    assert.same({ 2, 4, 6 }, Seq.from({ 1, 2, 3 }):map(function(x) return x * 2 end):collect())
  end)

  it("identity on empty", function()
    assert.same({}, Seq.from({}):map(function(x) return x end):collect())
  end)

  it("type-changing (number -> table)", function()
    local r = Seq.from({ 1, 2 }):map(function(x) return { v = x } end):collect()
    assert.equal(1, r[1].v)
    assert.equal(2, r[2].v)
  end)

  it("chained same-combinator long run (protopool rotation)", function()
    local seq = Seq.from(D.sequential_ints(200))
    for _ = 1, 60 do
      seq = seq:map(function(x) return x + 1 end)
    end
    assert.equal(61, seq:collect()[1])
  end)

  it("rejects non-function fn", function()
    assert.has_error(function() Seq.from({ 1 }):map(5) end, "map: fn must be a function")
  end)

  it("on nested record data", function()
    local t = D.nested_records(20)
    local names = Seq.from(t):map(function(r) return r.name end):collect()
    assert.equal("user_1", names[1])
    assert.equal(20, #names)
  end)
end)

describe("filter", function()
  it("keeps evens", function()
    assert.same({ 2, 4, 6 },
      Seq.from({ 1, 2, 3, 4, 5, 6 }):filter(function(x) return x % 2 == 0 end):collect())
  end)

  it("predicate always false yields empty", function()
    assert.same({}, Seq.from({ 1, 2, 3 }):filter(function() return false end):collect())
  end)

  it("predicate always true yields all", function()
    assert.same({ 1, 2, 3 }, Seq.from({ 1, 2, 3 }):filter(function() return true end):collect())
  end)

  it("long run of consecutive rejects (recursion depth)", function()
    local t = D.sequential_ints(100000)
    local r = Seq.from(t):filter(function(x) return x == 100000 end):collect()
    assert.same({ 100000 }, r)
  end)

  it("predicate distinguishes false from true 0", function()
    local t = { 0, false, 1, true, "" }
    local r = Seq.from(t):filter(function(x) return x ~= false end):collect()
    assert.same({ 0, 1, true, "" }, r)
  end)

  it("rejects non-function pred", function()
    assert.has_error(function() Seq.from({ 1 }):filter("x") end, "filter: pred must be a function")
  end)
end)

describe("take / take_while", function()
  it("fewer than available", function()
    assert.same({ 1, 2 }, Seq.from({ 1, 2, 3, 4, 5 }):take(2):collect())
  end)

  it("more than available stops at source end", function()
    assert.same({ 1, 2 }, Seq.from({ 1, 2 }):take(100):collect())
  end)

  it("zero yields empty", function()
    assert.same({}, Seq.from({ 1, 2, 3 }):take(0):collect())
  end)

  it("on infinite repeat_ source", function()
    assert.same({ 1, 1, 1, 1, 1 }, Seq.repeat_(1):take(5):collect())
  end)

  it("rejects negative n", function()
    assert.has_error(function() Seq.from({ 1 }):take(-1) end, "take: n must be a non-negative number")
  end)

  it("take_while: stops at first failure", function()
    assert.same({ 1, 2, 3 },
      Seq.from({ 1, 2, 3, 10, 1, 2 }):take_while(function(x) return x < 5 end):collect())
  end)

  it("take_while: never matches yields empty", function()
    assert.same({}, Seq.from({ 5, 6, 7 }):take_while(function(x) return x < 0 end):collect())
  end)

  it("take_while: always matches yields all", function()
    assert.same({ 1, 2, 3 }, Seq.from({ 1, 2, 3 }):take_while(function() return true end):collect())
  end)

  it("take_while: on infinite source terminates", function()
    assert.same({ 1, 2, 3 },
      Seq.range(1, math.huge):take_while(function(x) return x <= 3 end):collect())
  end)
end)

describe("drop / drop_while", function()
  it("fewer than available", function()
    assert.same({ 3, 4, 5 }, Seq.from({ 1, 2, 3, 4, 5 }):drop(2):collect())
  end)

  it("more than available yields empty", function()
    assert.same({}, Seq.from({ 1, 2 }):drop(100):collect())
  end)

  it("zero yields all", function()
    assert.same({ 1, 2, 3 }, Seq.from({ 1, 2, 3 }):drop(0):collect())
  end)

  it("long run of consecutive skips", function()
    local t = D.sequential_ints(50000)
    local r = Seq.from(t):drop(49999):collect()
    assert.same({ 50000 }, r)
  end)

  it("rejects negative n", function()
    assert.has_error(function() Seq.from({ 1 }):drop(-1) end, "drop: n must be a non-negative number")
  end)

  it("drop_while: skips prefix matching pred", function()
    assert.same({ 10, 1, 2 },
      Seq.from({ 1, 2, 3, 10, 1, 2 }):drop_while(function(x) return x < 5 end):collect())
  end)

  it("drop_while: nothing dropped when pred fails immediately", function()
    assert.same({ 5, 1, 2 }, Seq.from({ 5, 1, 2 }):drop_while(function(x) return x < 0 end):collect())
  end)

  it("drop_while: everything dropped when pred always holds", function()
    assert.same({}, Seq.from({ 1, 2, 3 }):drop_while(function() return true end):collect())
  end)

  it("drop_while: includes the first failing element", function()
    assert.same({ 5, 6 },
      Seq.from({ 2, 4, 5, 6 }):drop_while(function(x) return x % 2 == 0 end):collect())
  end)
end)

describe("scan", function()
  it("running sum", function()
    assert.same({ 1, 3, 6, 10 },
      Seq.from({ 1, 2, 3, 4 }):scan(function(acc, v) return acc + v end, 0):collect())
  end)

  it("empty source yields empty", function()
    assert.same({}, Seq.from({}):scan(function(acc, v) return acc + v end, 0):collect())
  end)

  it("init never yielded on its own for non-empty source", function()
    local r = Seq.from({ 5 }):scan(function(acc, v) return acc + v end, 100):collect()
    assert.same({ 105 }, r)
  end)

  it("accumulator can change type from init", function()
    local r = Seq.from({ 1, 2, 3 }):scan(function(acc, v) return acc .. v end, ""):collect()
    assert.same({ "1", "12", "123" }, r)
  end)

  it("numeric stability on random floats sums to reduce()'s result", function()
    local t = D.uniform_floats(1000)
    local scanned = Seq.from(t):scan(function(a, v) return a + v end, 0):collect()
    local reduced = Seq.from(t):reduce(function(a, v) return a + v end, 0)
    assert.equal(reduced, scanned[#scanned])
  end)
end)

describe("chain", function()
  it("concatenates two sequences", function()
    assert.same({ 1, 2, 3, 4 }, Seq.from({ 1, 2 }):chain(Seq.from({ 3, 4 })):collect())
  end)

  it("first empty falls through to second", function()
    assert.same({ 1, 2 }, Seq.from({}):chain(Seq.from({ 1, 2 })):collect())
  end)

  it("second empty yields only first", function()
    assert.same({ 1, 2 }, Seq.from({ 1, 2 }):chain(Seq.from({})):collect())
  end)

  it("both empty yields empty", function()
    assert.same({}, Seq.from({}):chain(Seq.from({})):collect())
  end)

  it("rejects non-Seq other", function()
    assert.has_error(function() Seq.from({ 1 }):chain({ 1, 2 }) end, "chain: other must be a Seq")
  end)

  it("three-way chain via nesting", function()
    local r = Seq.from({ 1 }):chain(Seq.from({ 2 })):chain(Seq.from({ 3 })):collect()
    assert.same({ 1, 2, 3 }, r)
  end)
end)

describe("enumerate", function()
  it("1-based index paired with value", function()
    local idx, val = {}, {}
    drive(Seq.from({ "a", "b", "c" }):enumerate(), function(i, v)
      idx[#idx + 1] = i
      val[#val + 1] = v
    end)
    assert.same({ 1, 2, 3 }, idx)
    assert.same({ "a", "b", "c" }, val)
  end)

  it("empty source yields no pairs", function()
    local n = 0
    drive(Seq.from({}):enumerate(), function() n = n + 1 end)
    assert.equal(0, n)
  end)

  it("composes after filter (index reflects post-filter position)", function()
    local idx = {}
    drive(
      Seq.from({ 10, 20, 30, 40 }):filter(function(x) return x > 15 end):enumerate(),
      function(i, v) idx[#idx + 1] = { i, v } end
    )
    assert.same({ { 1, 20 }, { 2, 30 }, { 3, 40 } }, idx)
  end)
end)

describe("zip", function()
  it("equal length sequences", function()
    local pairs_out = {}
    drive(Seq.from({ 1, 2, 3 }):zip(Seq.from({ "a", "b", "c" })), function(a, b)
      pairs_out[#pairs_out + 1] = { a, b }
    end)
    assert.same({ { 1, "a" }, { 2, "b" }, { 3, "c" } }, pairs_out)
  end)

  it("stops at shorter left side", function()
    local n = 0
    drive(Seq.from({ 1, 2 }):zip(Seq.from({ "a", "b", "c", "d" })), function() n = n + 1 end)
    assert.equal(2, n)
  end)

  it("stops at shorter right side", function()
    local n = 0
    drive(Seq.from({ 1, 2, 3, 4 }):zip(Seq.from({ "a", "b" })), function() n = n + 1 end)
    assert.equal(2, n)
  end)

  it("either side empty yields empty", function()
    local n = 0
    drive(Seq.from({}):zip(Seq.from({ 1, 2 })), function() n = n + 1 end)
    assert.equal(0, n)
  end)

  it("rejects non-Seq other", function()
    assert.has_error(function() Seq.from({ 1 }):zip({ 1 }) end, "zip: other must be a Seq")
  end)

  it("zipping a seq with itself advances both sides independently", function()
    local a = Seq.from({ 1, 2, 3 })
    local pairs_out = {}
    drive(a:zip(a), function(x, y) pairs_out[#pairs_out + 1] = { x, y } end)
    assert.same({ { 1, 1 }, { 2, 2 }, { 3, 3 } }, pairs_out)
  end)
end)

describe("flat_map", function()
  it("expands each element into a Seq", function()
    local r = Seq.from({ 1, 2, 3 }):flat_map(function(x) return Seq.range(1, x) end):collect()
    assert.same({ 1, 1, 2, 1, 2, 3 }, r)
  end)

  it("expands via plain array table", function()
    local r = Seq.from({ 1, 2 }):flat_map(function(x) return { x, x * 10 } end):collect()
    assert.same({ 1, 10, 2, 20 }, r)
  end)

  it("inner empty sequences are skipped", function()
    local r = Seq.from({ 1, 2, 3 }):flat_map(function(x)
      if x == 2 then return Seq.from({}) end
      return Seq.from({ x })
    end):collect()
    assert.same({ 1, 3 }, r)
  end)

  it("all inner sequences empty yields empty", function()
    local r = Seq.from({ 1, 2, 3 }):flat_map(function() return Seq.from({}) end):collect()
    assert.same({}, r)
  end)

  it("outer source empty yields empty without calling fn", function()
    local calls = 0
    local r = Seq.from({}):flat_map(function(x) calls = calls + 1; return Seq.from({ x }) end):collect()
    assert.same({}, r)
    assert.equal(0, calls)
  end)

  it("composes with map/filter downstream", function()
    local r = Seq.from({ 1, 2, 3 })
      :flat_map(function(x) return Seq.range(1, x) end)
      :filter(function(x) return x > 1 end)
      :collect()
    assert.same({ 2, 2, 3 }, r)
  end)

  it("rejects non-function fn", function()
    assert.has_error(function() Seq.from({ 1 }):flat_map(1) end, "flat_map: fn must be a function")
  end)
end)
