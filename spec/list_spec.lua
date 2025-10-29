-- list_spec.lua
-- Unit tests for List class

describe("List Module", function()
    local randomizer

    setup(function()
        randomizer = require("randomizer")
    end)

    describe("Constructor and Basic Operations", function()
        it("should create a list and convert back to table", function()
            local items = {1, 2, 3, 4, 5}
            local list = randomizer.list(items)

            assert.are.equal(5, list:size())
            assert.is_false(list:isEmpty())

            local result = list:toTable()
            assert.are.same({1, 2, 3, 4, 5}, result)
        end)

        it("should handle empty lists gracefully", function()
            local list = randomizer.list({})
            assert.is_true(list:isEmpty())
            assert.are.equal(0, list:size())
        end)

        it("should get item at specific index", function()
            local list = randomizer.list({"a", "b", "c"})
            assert.are.equal("a", list:get(1))
            assert.are.equal("b", list:get(2))
            assert.are.equal("c", list:get(3))
        end)

        it("should have string representation", function()
            local list = randomizer.list({1, 2, 3})
            local str = tostring(list)
            assert.are.equal("List(3 items)", str)
        end)
    end)

    describe("Filter", function()
        it("should filter items from a list", function()
            local list = randomizer.list({1, 2, 3, 4, 5, 6})
            local filtered = list:filter(function(x) return x > 3 end)

            assert.are.same({4, 5, 6}, filtered:toTable())
        end)
    end)

    describe("Remove Duplicates", function()
        it("should remove duplicates from a list", function()
            local list = randomizer.list({1, 2, 2, 3, 3, 3, 4})
            local unique = list:removeDuplicates()

            assert.are.same({1, 2, 3, 4}, unique:toTable())
        end)

        it("should remove duplicate tables using serialization", function()
            local list = randomizer.list({
                {id = 1, name = "a"},
                {id = 2, name = "b"},
                {id = 1, name = "a"},  -- duplicate
                {id = 3, name = "c"},
                {id = 2, name = "b"}   -- duplicate
            })

            local unique = list:removeDuplicates()
            local result = unique:toTable()

            assert.are.equal(3, #result)
        end)
    end)

    describe("Sort", function()
        it("should sort a list", function()
            local list = randomizer.list({5, 2, 8, 1, 9})
            local sorted = list:sort()

            assert.are.same({1, 2, 5, 8, 9}, sorted:toTable())
        end)

        it("should sort with custom comparator", function()
            local list = randomizer.list({5, 2, 8, 1, 9})
            local sorted = list:sort(function(a, b) return a > b end)

            assert.are.same({9, 8, 5, 2, 1}, sorted:toTable())
        end)
    end)

    describe("Select", function()
        it("should select items by indices", function()
            local list = randomizer.list({"a", "b", "c", "d", "e"})
            local selected = list:select({1, 3, 5})

            assert.are.same({"a", "c", "e"}, selected:toTable())
        end)

        it("should select single item by index", function()
            local list = randomizer.list({"a", "b", "c", "d"})
            local selected = list:select(2)  -- Single number, not table
            assert.are.same({"b"}, selected:toTable())
        end)
    end)

    describe("Shuffle", function()
        it("should shuffle items", function()
            randomizer.setSeed(42)
            local list = randomizer.list({1, 2, 3, 4, 5})
            local shuffled = list:shuffle()

            -- Should have same elements
            local sorted = randomizer.sort(shuffled:toTable())
            assert.are.same({1, 2, 3, 4, 5}, sorted)
        end)
    end)

    describe("Chaining", function()
        it("should chain multiple operations", function()
            local list = randomizer.list({5, 2, 8, 2, 1, 9, 5, 3})
            local result = list:removeDuplicates():sort():filter(function(x) return x > 3 end)

            assert.are.same({5, 8, 9}, result:toTable())
        end)
    end)

    describe("Randomization", function()
        before_each(function()
            randomizer.setSeed(42)
        end)

        it("should randomize a target list from a list pool", function()
            local target = {"A", "B", "C"}
            local pool = randomizer.list({"X", "Y", "Z"})

            local result = pool:randomize(target)

            -- Should modify in place
            assert.are.equal(target, result)
            -- All items should be from the pool
            for _, item in ipairs(result) do
                assert.is_true(item == "X" or item == "Y" or item == "Z")
            end
        end)

        it("should error when randomizing from empty list", function()
            local list = randomizer.list({})
            local target = {1, 2, 3}

            assert.has_error(function()
                list:randomize(target)
            end)
        end)
    end)

    describe("Immutability", function()
        it("should preserve immutability in operations", function()
            local original = randomizer.list({3, 1, 2})
            local sorted = original:sort()

            -- Original should be unchanged
            assert.are.same({3, 1, 2}, original:toTable())
            -- Sorted should be different
            assert.are.same({1, 2, 3}, sorted:toTable())
        end)
    end)
end)

