local D = require("datagen")
local Seq = require("seq")

local N = 200000

describe("performance", function()
  it("seq pipeline vs hand-rolled loop", function()
    local n = 2000000
    local t = D.sequential_ints(n)

    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("stop")

    local t0 = os.clock()
    local seq_result = Seq.from(t)
      :map(function(x) return x * 2 end)
      :filter(function(x) return x % 3 == 0 end)
      :take(100000)
      :collect()
    local t1 = os.clock()

    collectgarbage("collect")
    local t2 = os.clock()
    local hand_result, hn = {}, 0
    for i = 1, n do
      if hn >= 100000 then break end
      local v = t[i] * 2
      if v % 3 == 0 then
        hn = hn + 1
        hand_result[hn] = v
      end
    end
    local t3 = os.clock()
    collectgarbage("restart")

    assert.same(hand_result, seq_result)

    local seq_time, hand_time = t1 - t0, t3 - t2
    print(("\n[perf] seq=%.4fs hand=%.4fs ratio=%.2fx")
      :format(seq_time, hand_time, seq_time / math.max(hand_time, 1e-9)))

    assert.is_true(seq_time < hand_time * 10 + 1, "seq pipeline unexpectedly slow vs hand-rolled loop")
  end)

  it("from_pairs pipeline completes on large table", function()
    local n = 300000
    local t = {}
    for i = 1, n do t["k" .. i] = i end

    collectgarbage("collect")
    collectgarbage("collect")

    local t0 = os.clock()
    local count = Seq.from_pairs(t)
      :filter2(function(k, v) return v % 2 == 0 end)
      :map2(function(k, v) return v end)
      :values()
      :length()
    local t1 = os.clock()

    assert.equal(n / 2, count)
    print(("\n[perf] from_pairs n=%d elapsed=%.4fs"):format(n, t1 - t0))
  end)
end)

describe("end-to-end pipelines", function()
  it("canonical example", function()
    local result = Seq.from({ 1, 2, 3, 4, 5 })
      :map(function(x) return x * 2 end)
      :filter(function(x) return x > 4 end)
      :take(2)
      :collect()
    assert.same({ 6, 8 }, result)
  end)

  it("all single-value combinators chained, matches hand-rolled loop", function()
    local t = D.sequential_ints(N)

    local pipeline = Seq.from(t)
      :map(function(x) return x + 1 end)
      :filter(function(x) return x % 2 == 0 end)
      :drop(10)
      :take_while(function(x) return x < N end)
      :drop_while(function(x) return x < 100 end)
      :scan(function(acc, x) return acc + x end, 0)
      :take(50)
      :enumerate()

    local seq_result = {}
    for _, i, v in pipeline.gen, pipeline.param, pipeline.state do
      seq_result[#seq_result + 1] = { i, v }
    end

    local hand = {}
    do
      local mapped, filtered = {}, {}
      for i = 1, #t do mapped[i] = t[i] + 1 end
      for _, v in ipairs(mapped) do
        if v % 2 == 0 then filtered[#filtered + 1] = v end
      end
      local dropped = {}
      for i = 11, #filtered do dropped[#dropped + 1] = filtered[i] end
      local taken_while = {}
      for _, v in ipairs(dropped) do
        if v < N then taken_while[#taken_while + 1] = v else break end
      end
      local dropped_while, dropping = {}, true
      for _, v in ipairs(taken_while) do
        if not (dropping and v < 100) then
          dropping = false
          dropped_while[#dropped_while + 1] = v
        end
      end
      local scanned, acc = {}, 0
      for _, v in ipairs(dropped_while) do
        acc = acc + v
        scanned[#scanned + 1] = acc
      end
      for i = 1, math.min(50, #scanned) do
        hand[i] = { i, scanned[i] }
      end
    end

    assert.equal(#hand, #seq_result)
    for i = 1, #hand do
      assert.equal(hand[i][1], seq_result[i][1], "index at position " .. i)
      assert.equal(hand[i][2], seq_result[i][2], "value at position " .. i)
    end
  end)

  it("chain + zip + flat_map combined", function()
    local a = Seq.from(D.sequential_ints(100))
    local b = Seq.from(D.sequential_ints(100, 101))
    local chained = a:chain(b)
    local zipped = {}
    Seq.from(D.sequential_ints(200)):zip(chained):each(function(x) zipped[#zipped + 1] = x end)
    assert.equal(200, #zipped)

    local flat = Seq.from({ 1, 2, 3, 4 })
      :flat_map(function(x) return Seq.range(1, x) end)
      :collect()
    assert.same({ 1, 1, 2, 1, 2, 3, 1, 2, 3, 4 }, flat)
  end)

  it("full from_pairs chain crossing into single-value family", function()
    local t = {}
    for i = 1, N do t["k" .. i] = i end

    local result = Seq.from_pairs(t)
      :filter2(function(k, v) return v % 2 == 0 end)
      :map2(function(k, v) return v * 10 end)
      :scan2(function(acc, k, v) return acc + 1 end, 0)
      :values()
      :filter(function(count) return count % 100 == 0 end)
      :take(5)
      :collect()

    assert.same({ 100, 200, 300, 400, 500 }, result)
  end)

  it("chain2 then keys() then downstream single-value chain", function()
    local a, b = {}, {}
    for i = 1, 50 do a["a" .. i] = i end
    for i = 1, 50 do b["b" .. i] = i end

    local prefixes = Seq.from_pairs(a):chain2(Seq.from_pairs(b))
      :keys()
      :map(function(k) return k:sub(1, 1) end)
      :filter(function(p) return p == "a" end)
      :length()

    assert.equal(50, prefixes)
  end)

  it("realistic pipeline over nested record data", function()
    local records = D.nested_records(5000)

    local pipeline = Seq.from(records)
      :filter(function(r) return r.active end)
      :filter(function(r) return r.email ~= D.NONE end)
      :map(function(r) return { id = r.id, score = r.score, ntags = #r.tags } end)
      :filter(function(r) return r.score > 0 end)
      :scan(function(acc, r) return acc + r.score end, 0)
      :enumerate()

    local report = {}
    for _, i, v in pipeline.gen, pipeline.param, pipeline.state do
      report[#report + 1] = { i, v }
    end

    assert.is_true(#report > 0)
    for i = 2, #report do
      assert.is_true(report[i][2] >= report[i - 1][2], "scan accumulator must be non-decreasing")
    end
  end)

  it("terminal ops agree with each other on identical pipeline", function()
    local function pipeline()
      return Seq.from(D.sequential_ints(10000)):filter(function(x) return x % 7 == 0 end)
    end

    local collected = pipeline():collect()
    local counted    = pipeline():length()
    local reduced    = pipeline():reduce(function(acc, v) acc[#acc + 1] = v; return acc end, {})
    local all_mod7   = pipeline():all(function(x) return x % 7 == 0 end)
    local any_gt9990 = pipeline():any(function(x) return x > 9990 end)
    local found      = pipeline():find(function(x) return x == 70 end)

    assert.equal(counted, #collected)
    assert.same(reduced, collected)
    assert.is_true(all_mod7)
    assert.is_true(any_gt9990)
    assert.equal(70, found)
  end)

  it("take() is single-use: second full drain differs from the first", function()
    local seq = Seq.from({ 1, 2, 3, 4, 5 }):take(3)
    local first = seq:collect()
    local second = seq:collect()
    assert.same({ 1, 2, 3 }, first)
    assert.same({}, second)
  end)
end)

describe("protopool rotation past pool size", function()
  it("60-stage map chain exceeds pool size, stays correct", function()
    local seq = Seq.from(D.sequential_ints(1000))
    for _ = 1, 60 do
      seq = seq:map(function(x) return x + 1 end)
    end
    local r = seq:collect()
    assert.equal(61, r[1])
    assert.equal(1060, r[1000])
  end)

  it("60-stage filter chain (all-pass) exceeds pool size, stays correct", function()
    local seq = Seq.from(D.sequential_ints(500))
    for _ = 1, 60 do
      seq = seq:filter(function(x) return true end)
    end
    assert.same(D.sequential_ints(500), seq:collect())
  end)

  it("mixed 60-stage map/filter alternation", function()
    local seq = Seq.from(D.sequential_ints(2000))
    for i = 1, 60 do
      if i % 2 == 0 then
        seq = seq:filter(function(x) return x % 2 == 0 end)
      else
        seq = seq:map(function(x) return x + 1 end)
      end
    end
    assert.equal(0, seq:length())
  end)
end)