-- init_spec.lua
-- Unit tests for standalone functions and main module

describe("Init Module - Standalone Functions", function()
    local randomizer

    setup(function()
        randomizer = require("randomizer")
    end)

    describe("Standalone Shuffle", function()
        it("should shuffle a plain table", function()
            randomizer.setSeed(123)
            local original = {1, 2, 3, 4, 5}
            local shuffled = randomizer.shuffle(original)

            -- Should not modify original
            assert.are.same({1, 2, 3, 4, 5}, original)

            -- Shuffled should have same elements
            table.sort(shuffled)
            assert.are.same({1, 2, 3, 4, 5}, shuffled)
        end)
    end)

    describe("Standalone Filter", function()
        it("should filter a plain table", function()
            local filtered = randomizer.filter({1, 2, 3, 4, 5}, function(x) return x > 3 end)
            assert.are.same({4, 5}, filtered)
        end)
    end)

    describe("Standalone Remove Duplicates", function()
        it("should remove duplicates from plain table", function()
            local unique = randomizer.removeDuplicates({1, 2, 2, 3, 3, 3})
            assert.are.same({1, 2, 3}, unique)
        end)
    end)

    describe("Standalone Sort", function()
        it("should sort a plain table", function()
            local sorted = randomizer.sort({5, 2, 8, 1})
            assert.are.same({1, 2, 5, 8}, sorted)
        end)

        it("should sort with custom comparator", function()
            local sorted = randomizer.sort({5, 2, 8, 1}, function(a, b)
                return a > b
            end)
            assert.are.same({8, 5, 2, 1}, sorted)
        end)
    end)

    describe("Standalone Select Random", function()
        it("should select random elements", function()
            randomizer.setSeed(456)
            local pool = {1, 2, 3, 4, 5}
            local selected = randomizer.selectRandom(pool, 3)

            assert.are.equal(3, #selected)
            -- All selected should be from pool
            for _, item in ipairs(selected) do
                local found = false
                for _, poolItem in ipairs(pool) do
                    if item == poolItem then
                        found = true
                        break
                    end
                end
                assert.is_true(found)
            end
        end)
    end)

    describe("Universal Randomize Function", function()
        before_each(function()
            randomizer.setSeed(42)
        end)

        it("should work with plain table", function()
            local target = {1, 2, 3, 4}
            local pool = {10, 20, 30}

            randomizer.randomize(target, pool)

            -- All items should be from the pool
            for _, item in ipairs(target) do
                assert.is_true(item == 10 or item == 20 or item == 30)
            end
        end)

        it("should work with List instance", function()
            local target = {1, 2, 3}
            local pool = randomizer.list({10, 20, 30})

            randomizer.randomize(target, pool)

            for _, item in ipairs(target) do
                assert.is_true(item == 10 or item == 20 or item == 30)
            end
        end)

        it("should work with Group instance", function()
            local items = {"a", "b", "c"}
            local groups = randomizer.group({
                vowel = {"A", "E", "I"},
                consonant = {"B", "C", "D"}
            })

            local function isVowel(char)
                return char == "a" or char == "e" or char == "i" or char == "o" or char == "u"
            end

            randomizer.randomize(items, groups, function(item)
                return isVowel(item) and "vowel" or "consonant"
            end)

            -- Verify first item (vowel) came from vowel pool
            assert.is_true(items[1] == "A" or items[1] == "E" or items[1] == "I")

            -- Verify second and third items (consonants) came from consonant pool
            assert.is_true(items[2] == "B" or items[2] == "C" or items[2] == "D")
            assert.is_true(items[3] == "B" or items[3] == "C" or items[3] == "D")
        end)

        it("should error when source is invalid type", function()
            local target = {1, 2, 3}

            assert.has_error(function()
                randomizer.randomize(target, "not a valid source")
            end)
        end)
    end)

    describe("Module Metadata", function()
        it("should have version information", function()
            assert.are.equal("1.0.0", randomizer._VERSION)
            assert.is_string(randomizer._DESCRIPTION)
        end)

        it("should expose List class", function()
            assert.is_table(randomizer.List)
            assert.is_function(randomizer.List.new)
        end)

        it("should expose Group class", function()
            assert.is_table(randomizer.Group)
            assert.is_function(randomizer.Group.new)
        end)
    end)
end)

