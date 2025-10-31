-- utils_spec.lua
-- Unit tests for utility helpers

local utils = require("randomizer.utils")

describe("Utils Module", function()
    describe("extractValue", function()
        it("should extract a field value by name", function()
            local obj = { value = 42 }
            local result = utils.extractValue(obj, "value")
            assert.are.equal(42, result)
        end)

        it("should call a method when using a method name", function()
            local Object = {}
            Object.__index = Object

            function Object:new(value)
                local instance = setmetatable({}, Object)
                instance.value = value
                return instance
            end

            function Object:getValue(multiplier)
                return self.value * multiplier
            end

            local obj = Object:new(10)
            local result = utils.extractValue(obj, "getValue", 3)
            assert.are.equal(30, result)
        end)

        it("should invoke a provided function extractor", function()
            local obj = { value = 5 }
            local result = utils.extractValue(obj, function(subject, factor)
                return subject.value + factor
            end, 7)

            assert.are.equal(12, result)
        end)

        it("should return nil when field is missing", function()
            local obj = { other = 1 }
            local result = utils.extractValue(obj, "value")
            assert.is_nil(result)
        end)

        it("should return nil when subject is not a table for string extractor", function()
            local result = utils.extractValue(123, "value")
            assert.is_nil(result)
        end)

        it("should access values via __index metamethod", function()
            local proxy = setmetatable({}, {
                __index = function(_, key)
                    if key == "getValue" then
                        return function(self, multiplier)
                            return (self.base or 7) * multiplier
                        end
                    elseif key == "value" then
                        return 99
                    end
                end
            })
            proxy.base = 7

            local methodResult = utils.extractValue(proxy, "getValue", 2)
            assert.are.equal(14, methodResult)

            local fieldResult = utils.extractValue(proxy, "value")
            assert.are.equal(99, fieldResult)
        end)

        it("should error when extractor type is invalid", function()
            assert.has_error(function()
                utils.extractValue({}, 123)
            end)
        end)
    end)
end)
-- utils_spec.lua
-- Unit tests for utility functions

describe("Utils Module", function()
    local utils

    setup(function()
        utils = require("randomizer.utils")
    end)

    describe("Shuffle", function()
        it("should shuffle a table", function()
            local randomizer = require("randomizer")
            randomizer.setSeed(42)

            local tbl = {1, 2, 3, 4, 5}
            utils.shuffle(tbl)

            -- Should have same elements
            table.sort(tbl)
            assert.are.same({1, 2, 3, 4, 5}, tbl)
        end)
    end)

    describe("Deep Copy", function()
        it("should deepCopy non-table values", function()
            assert.are.equal(42, utils.deepCopy(42))
            assert.are.equal("hello", utils.deepCopy("hello"))
            assert.are.equal(true, utils.deepCopy(true))
            assert.is_nil(utils.deepCopy(nil))
        end)

        it("should deepCopy tables", function()
            local original = {a = 1, b = 2, c = {d = 3}}
            local copy = utils.deepCopy(original)

            -- Should have same values
            assert.are.equal(1, copy.a)
            assert.are.equal(2, copy.b)
            assert.are.equal(3, copy.c.d)

            -- Should be different table
            assert.are_not.equal(original, copy)

            -- Modifying copy shouldn't affect original
            copy.a = 999
            assert.are.equal(1, original.a)
        end)

        it("should deepCopy table with metatable", function()
            local mt = {__tostring = function() return "test" end}
            local original = setmetatable({a = 1}, mt)

            local copy = utils.deepCopy(original)

            assert.are.equal(1, copy.a)
            assert.are.equal(mt, getmetatable(copy))
            assert.are.equal("test", tostring(copy))
        end)
    end)

    describe("Remove Duplicates", function()
        it("should remove duplicates from array", function()
            local result = utils.removeDuplicates({1, 2, 2, 3, 3, 3, 4})
            assert.are.same({1, 2, 3, 4}, result)
        end)

        it("should handle empty array", function()
            local result = utils.removeDuplicates({})
            assert.are.same({}, result)
        end)
    end)

    describe("Serialization", function()
        it("should serialize tables for comparison", function()
            local tbl1 = {a = 1, b = 2}
            local tbl2 = {b = 2, a = 1}  -- Same content, different order

            local ser1 = utils.serializeForComparison(tbl1)
            local ser2 = utils.serializeForComparison(tbl2)

            -- Should be equal because serialization sorts keys
            assert.are.equal(ser1, ser2)
        end)

        it("should serialize non-table values", function()
            assert.are.equal("42", utils.serializeForComparison(42))
            assert.are.equal("hello", utils.serializeForComparison("hello"))
        end)

        it("should serialize nested tables", function()
            local tbl = {
                a = 1,
                b = {
                    c = 2,
                    d = 3
                }
            }

            local serialized = utils.serializeForComparison(tbl)
            assert.is_string(serialized)
            assert.is_true(#serialized > 0)
        end)
    end)

    describe("Type Checking", function()
        it("should check if value is List", function()
            local randomizer = require("randomizer")
            local list = randomizer.list({1, 2, 3})

            assert.is_true(utils.isList(list))
            assert.is_false(utils.isList({1, 2, 3}))
            assert.is_false(utils.isList("not a list"))
        end)

        it("should check if value is Group", function()
            local randomizer = require("randomizer")
            local group = randomizer.group({a = {1, 2}})

            assert.is_true(utils.isGroup(group))
            assert.is_false(utils.isGroup({a = {1, 2}}))
            assert.is_false(utils.isGroup("not a group"))
        end)

        it("should check if table is array-like", function()
            assert.is_true(utils.isArray({1, 2, 3, 4}))
            assert.is_true(utils.isArray({}))
            assert.is_false(utils.isArray({a = 1, b = 2}))
            assert.is_false(utils.isArray({[1] = "a", [3] = "c"}))  -- Has gap
            assert.is_false(utils.isArray("not a table"))
            assert.is_false(utils.isArray(42))
        end)
    end)

    describe("Random Seed", function()
        it("should set random seed", function()
            local randomizer = require("randomizer")

            randomizer.setSeed(12345)
            local first = math.random(1, 100)

            randomizer.setSeed(12345)
            local second = math.random(1, 100)

            -- Same seed should produce same random number
            assert.are.equal(first, second)
        end)
    end)

    describe("Random Element", function()
        it("should get random element from table", function()
            local tbl = {10, 20, 30}
            local element = utils.randomElement(tbl)

            -- Should be one of the elements
            assert.is_true(element == 10 or element == 20 or element == 30)
        end)

        it("should error on empty table", function()
            assert.has_error(function()
                utils.randomElement({})
            end)
        end)
    end)

    describe("Select Random", function()
        it("should select multiple random elements", function()
            local randomizer = require("randomizer")
            randomizer.setSeed(456)

            local tbl = {1, 2, 3, 4, 5}
            local selected = utils.selectRandom(tbl, 3)

            assert.are.equal(3, #selected)
            -- All selected should be from table
            for _, item in ipairs(selected) do
                local found = false
                for _, tableItem in ipairs(tbl) do
                    if item == tableItem then
                        found = true
                        break
                    end
                end
                assert.is_true(found)
            end
        end)

        it("should error on empty table", function()
            assert.has_error(function()
                utils.selectRandom({}, 3)
            end)
        end)
    end)
end)

