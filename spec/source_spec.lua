local D = require("datagen")
local Seq = require("seq")

describe("Seq.from", function()
  it("creates a sequence from an array", function()
    assert.same({ 1, 2, 3 }, Seq.from({ 1, 2, 3 }):collect())
    assert.equal(3, Seq.from({ 1, 2, 3 }):length())
  end)

  it("creates a sequence from an empty array", function()
    assert.same({}, Seq.from({}):collect())
    assert.equal(0, Seq.from({}):length())
  end)

  it("creates a sequence from a single element", function()
    assert.same({ 42 }, Seq.from({ 42 }):collect())
    assert.equal(1, Seq.from({ 42 }):length())
  end)

  it("creates a sequence from a large array, preserving order", function()
    local t = D.sequential_ints(50000)
    assert.same(t, Seq.from(t):collect())
  end)

  it("creates a sequence from mixed scalar types round-trip", function()
    local t = D.mixed_scalars()
    assert.same(t, Seq.from(t):collect())
    assert.equal(#t, Seq.from(t):length())
  end)

  it("nested record tables preserved by reference", function()
    local t = D.nested_records(10)
    local r = Seq.from(t):collect()
    assert.equal(#t, #r)
    for i = 1, #t do
      assert.equal(t[i], r[i])
    end
  end)

  it("returns a Seq, not a plain table", function()
    local s = Seq.from({ 1 })
    assert.is_not_nil(getmetatable(s))
  end)
end)

describe("Seq.from_pairs", function()
  it("iterates every key/value pair in a table", function()
    local t = { a = 1, b = 2, c = 3 }
    local sum = Seq.from_pairs(t):values():reduce(function(acc, v) return acc + v end, 0)
    assert.equal(6, sum)
  end)

  it("creates a sequence from an empty table", function()
    assert.equal(0, Seq.from_pairs({}):values():length())
  end)

  it("covers every key in a sparse table of mixed key types", function()
    local t = D.sparse_keyed(30)
    local keys = Seq.from_pairs(t):keys():collect()
    local seen = {}
    for _, k in ipairs(keys) do seen[k] = true end
    for k in pairs(t) do
      assert.is_true(seen[k])
    end
  end)

  it("values match the source table by key", function()
    local t = D.sparse_keyed(15)
    local ok = Seq.from_pairs(t):map2(function(k, v) return v == t[k] end)
    :values():all(function(matched) return matched end)
    assert.is_true(ok)
  end)

  it("non-contiguous numeric keys don't confuse iteration", function()
    local t = { [100] = "a", [5] = "b", [999] = "c" }
    assert.equal(3, Seq.from_pairs(t):values():length())
  end)
end)

describe("Seq.range", function()
  it("ascending with the default step", function()
    assert.same({ 1, 2, 3, 4, 5 }, Seq.range(1, 5):collect())
  end)

  it("ascending with an explicit positive step", function()
    assert.same({ 0, 2, 4, 6, 8, 10 }, Seq.range(0, 10, 2):collect())
  end)

  it("descending with a negative step", function()
    assert.same({ 5, 4, 3, 2, 1 }, Seq.range(5, 1, -1):collect())
  end)

  it("yields empty when from > to with a positive step", function()
    assert.same({}, Seq.range(5, 1):collect())
  end)

  it("yields empty when from < to with a negative step", function()
    assert.same({}, Seq.range(1, 5, -1):collect())
  end)

  it("yields a single element when from == to", function()
    assert.same({ 3 }, Seq.range(3, 3):collect())
  end)

  it("supports a fractional step", function()
    assert.same({ 0, 0.25, 0.5, 0.75, 1 }, Seq.range(0, 1, 0.25):collect())
  end)

  it("supports negative bounds", function()
    assert.same({ -5, -4, -3, -2, -1 }, Seq.range(-5, -1):collect())
  end)

  it("asserts when step is 0", function()
    assert.has_error(function() Seq.range(1, 5, 0) end, "Seq.range: step must not be 0")
  end)

  it("produces an exact length over a large span", function()
    assert.equal(1000000, Seq.range(1, 1000000):length())
  end)

  it("excludes the final value when the step overshoots to", function()
    assert.same({ 1, 4, 7, 10 }, Seq.range(1, 10, 3):collect())
  end)
end)

describe("Seq.repeat_", function()
  it("repeats a value a bounded number of times", function()
    assert.same({ "x", "x", "x" }, Seq.repeat_("x", 3):collect())
  end)

  it("yields empty when count is 0", function()
    assert.same({}, Seq.repeat_("x", 0):collect())
  end)

  it("repeats forever when count is omitted, bounded by take", function()
    assert.same({ 7, 7, 7, 7 }, Seq.repeat_(7):take(4):collect())
  end)

  it("repeats a table by reference, not by copy", function()
    local v = { 1, 2, 3 }
    local r = Seq.repeat_(v, 3):collect()
    assert.is_true(r[1] == v and r[2] == v and r[3] == v)
  end)

  it("repeats false as a valid element, not as nil", function()
    assert.same({ false, false, false }, Seq.repeat_(false, 3):collect())
  end)

  it("asserts when n is negative", function()
    assert.has_error(function() Seq.repeat_("x", -1) end, "Seq.repeat_: n must be a non-negative number")
  end)
end)