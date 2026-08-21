local Seq = require("seq")

local ALLOC_THRESHOLD_BYTES_PER_ELEM = 1.0
local WARMUP_ELEMENTS = 200
local MEASURE_ELEMENTS = 50000

local function assert_allocation_free(label, build_fn)
  do
    local seq = build_fn()
    local n = 0
    for _ in seq.gen, seq.param, seq.state do
      n = n + 1
      if n >= WARMUP_ELEMENTS then break end
    end
  end

  collectgarbage("collect")
  collectgarbage("stop")
  
  local kb0 = collectgarbage("count")

  local seq = build_fn()
  local n = 0
  for _ in seq.gen, seq.param, seq.state do
    n = n + 1
  end

  local kb1 = collectgarbage("count")
  collectgarbage("restart")

  local bytes_per_elem = (kb1 - kb0) * 1024 / n
  assert.is_true(
    bytes_per_elem < ALLOC_THRESHOLD_BYTES_PER_ELEM,
    ("%s: %.4f bytes/element (n=%d), expected < %.1f")
      :format(label, bytes_per_elem, n, ALLOC_THRESHOLD_BYTES_PER_ELEM)
  )
end

describe("allocation ceiling (hot path)", function()
  local a, b = {}, {}
  for i = 1, MEASURE_ELEMENTS do a[i] = i; b[i] = i * 2 end

  local t, t2 = {}, {}
  for i = 1, MEASURE_ELEMENTS do t["k" .. i] = i; t2["k" .. i] = i * 2 end

  it("map", function()
    assert_allocation_free("map", function()
      return Seq.from(a):map(function(x) return x * 2 end)
    end)
  end)

  it("filter", function()
    assert_allocation_free("filter", function()
      return Seq.from(a):filter(function(x) return x % 2 == 0 end)
    end)
  end)

  it("take", function()
    assert_allocation_free("take", function()
      return Seq.from(a):take(MEASURE_ELEMENTS - 1)
    end)
  end)

  it("take_while", function()
    assert_allocation_free("take_while", function()
      return Seq.from(a):take_while(function(x) return x < MEASURE_ELEMENTS end)
    end)
  end)

  it("drop", function()
    assert_allocation_free("drop", function()
      return Seq.from(a):drop(10)
    end)
  end)

  it("drop_while", function()
    assert_allocation_free("drop_while", function()
      return Seq.from(a):drop_while(function(x) return x < 10 end)
    end)
  end)

  it("scan", function()
    assert_allocation_free("scan", function()
      return Seq.from(a):scan(function(acc, x) return acc + x end, 0)
    end)
  end)

  it("enumerate", function()
    assert_allocation_free("enumerate", function()
      return Seq.from(a):enumerate()
    end)
  end)

  it("chain", function()
    assert_allocation_free("chain", function()
      return Seq.from(a):chain(Seq.from(b))
    end)
  end)

  it("zip", function()
    assert_allocation_free("zip", function()
      return Seq.from(a):zip(Seq.from(b))
    end)
  end)

  it("flat_map (closure-free inner)", function()
    local inner = { 1, 2, 3 }
    assert_allocation_free("flat_map", function()
      return Seq.from(a):flat_map(function(x) return Seq.from(inner) end)
    end)
  end)

  it("map2", function()
    assert_allocation_free("map2", function()
      return Seq.from_pairs(t):map2(function(k, v) return v * 2 end)
    end)
  end)

  it("filter2", function()
    assert_allocation_free("filter2", function()
      return Seq.from_pairs(t):filter2(function(k, v) return v % 2 == 0 end)
    end)
  end)

  it("scan2", function()
    assert_allocation_free("scan2", function()
      return Seq.from_pairs(t):scan2(function(acc, k, v) return acc + v end, 0)
    end)
  end)

  it("chain2", function()
    assert_allocation_free("chain2", function()
      return Seq.from_pairs(t):chain2(Seq.from_pairs(t2))
    end)
  end)

  it("values", function()
    assert_allocation_free("values", function()
      return Seq.from_pairs(t):values()
    end)
  end)

  it("keys", function()
    assert_allocation_free("keys", function()
      return Seq.from_pairs(t):keys()
    end)
  end)
end)
