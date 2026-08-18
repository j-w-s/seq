local Seq = require("seq")

describe("seq", function()
    it("loads correctly", function()
        assert.is_not_nil(Seq)
        assert.is_same(type(Seq), "table")
    end)
end)