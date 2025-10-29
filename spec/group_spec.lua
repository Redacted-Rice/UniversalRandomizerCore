-- group_spec.lua
-- Unit tests for Group class

describe("Group Module", function()
    local randomizer

    setup(function()
        randomizer = require("randomizer")
    end)

    describe("Constructor and Basic Operations", function()
        it("should create a group from plain tables", function()
            local group = randomizer.group({
                type_a = {1, 2, 3},
                type_b = {4, 5, 6}
            })

            assert.are.equal(2, group:size())
            assert.is_false(group:isEmpty())
        end)

        it("should handle empty groups gracefully", function()
            local group = randomizer.group({})
            assert.is_true(group:isEmpty())
            assert.are.equal(0, group:size())
        end)

        it("should have string representation", function()
            local group = randomizer.group({
                a = {1, 2},
                b = {3, 4},
                c = {5, 6}
            })

            local str = tostring(group)
            assert.are.equal("Group(3 lists)", str)
        end)

        it("should error when creating group with invalid value", function()
            assert.has_error(function()
                randomizer.group({
                    a = {1, 2},
                    b = "not a table"
                })
            end)
        end)
    end)

    describe("Add and Remove", function()
        it("should add and remove lists from group", function()
            local group = randomizer.group({
                type_a = {1, 2, 3}
            })

            group:add("type_b", {4, 5, 6})
            assert.are.equal(2, group:size())

            group:remove("type_a")
            assert.are.equal(1, group:size())
        end)

        it("should add List instance to group", function()
            local group = randomizer.group({a = {1, 2}})
            local newList = randomizer.list({3, 4, 5})

            group:add("b", newList)

            assert.are.equal(2, group:size())
            assert.are.same({3, 4, 5}, group:get("b"):toTable())
        end)

        it("should error when adding non-table/list to group", function()
            local group = randomizer.group({a = {1, 2}})

            assert.has_error(function()
                group:add("b", "not a table")
            end)
        end)
    end)

    describe("Get and Keys", function()
        it("should get list by key", function()
            local group = randomizer.group({
                a = {1, 2, 3},
                b = {4, 5, 6}
            })

            local listA = group:get("a")
            assert.are.same({1, 2, 3}, listA:toTable())
        end)

        it("should return all keys", function()
            local group = randomizer.group({
                melee = {1, 2},
                ranged = {3, 4},
                magic = {5, 6}
            })

            local keys = group:keys()
            table.sort(keys)
            assert.are.same({"magic", "melee", "ranged"}, keys)
        end)
    end)

    describe("Filter", function()
        it("should filter all lists in a group", function()
            local group = randomizer.group({
                group1 = {1, 2, 3, 4, 5},
                group2 = {6, 7, 8, 9, 10}
            })

            local filtered = group:filter(function(x) return x % 2 == 0 end)
            local result = filtered:toTable()

            assert.are.same({2, 4}, result.group1)
            assert.are.same({6, 8, 10}, result.group2)
        end)
    end)

    describe("Remove Duplicates", function()
        it("should remove duplicates from all lists in a group", function()
            local group = randomizer.group({
                group1 = {1, 1, 2, 2, 3},
                group2 = {4, 4, 5, 5, 6}
            })

            local unique = group:removeDuplicates()
            local result = unique:toTable()

            assert.are.same({1, 2, 3}, result.group1)
            assert.are.same({4, 5, 6}, result.group2)
        end)
    end)

    describe("Shuffle", function()
        it("should shuffle all lists in group", function()
            randomizer.setSeed(42)
            local group = randomizer.group({
                a = {1, 2, 3, 4, 5},
                b = {6, 7, 8, 9, 10}
            })

            local shuffled = group:shuffle()
            local result = shuffled:toTable()

            -- Should have same elements but possibly different order
            table.sort(result.a)
            table.sort(result.b)
            assert.are.same({1, 2, 3, 4, 5}, result.a)
            assert.are.same({6, 7, 8, 9, 10}, result.b)
        end)
    end)

    describe("Sort", function()
        it("should sort all lists in group", function()
            local group = randomizer.group({
                a = {5, 2, 8, 1},
                b = {9, 3, 7, 4}
            })

            local sorted = group:sort()
            local result = sorted:toTable()

            assert.are.same({1, 2, 5, 8}, result.a)
            assert.are.same({3, 4, 7, 9}, result.b)
        end)

        it("should sort all lists with custom comparator", function()
            local group = randomizer.group({
                a = {1, 2, 3},
                b = {4, 5, 6}
            })

            local sorted = group:sort(function(a, b) return a > b end)
            local result = sorted:toTable()

            assert.are.same({3, 2, 1}, result.a)
            assert.are.same({6, 5, 4}, result.b)
        end)
    end)

    describe("GroupBy", function()
        it("should create groups from a list using keyExtractor", function()
            local items = {
                {name = "Apple", category = "fruit"},
                {name = "Carrot", category = "vegetable"},
                {name = "Banana", category = "fruit"},
                {name = "Broccoli", category = "vegetable"}
            }

            local grouped = randomizer.groupBy(items, function(item)
                return item.category
            end)

            assert.are.equal(2, grouped:size())

            local result = grouped:toTable()
            assert.are.equal(2, #result.fruit)
            assert.are.equal(2, #result.vegetable)
        end)

        it("should handle items with nil keys", function()
            local items = {
                {name = "Item1", category = "A"},
                {name = "Item2", category = nil},
                {name = "Item3", category = "B"}
            }

            local grouped = randomizer.groupBy(items, function(item)
                return item.category
            end)

            -- Should only have 2 groups (nil key items are skipped)
            assert.are.equal(2, grouped:size())
        end)
    end)

    describe("Randomization", function()
        before_each(function()
            randomizer.setSeed(99)
        end)

        it("should randomize based on selector function", function()
            local weapons = {
                {name = "weapon1", type = "melee"},
                {name = "weapon2", type = "ranged"},
                {name = "weapon3", type = "melee"},
                {name = "weapon4", type = "ranged"}
            }

            local pools = randomizer.group({
                melee = {"Sword", "Axe", "Mace"},
                ranged = {"Bow", "Gun", "Crossbow"}
            })

            local names = {}
            for i, weapon in ipairs(weapons) do
                names[i] = weapon.name
            end

            pools:randomize(names, function(name, index)
                return weapons[index].type
            end)

            -- Check that melee weapons got melee replacements
            assert.is_true(names[1] == "Sword" or names[1] == "Axe" or names[1] == "Mace")
            assert.is_true(names[3] == "Sword" or names[3] == "Axe" or names[3] == "Mace")

            -- Check that ranged weapons got ranged replacements
            assert.is_true(names[2] == "Bow" or names[2] == "Gun" or names[2] == "Crossbow")
            assert.is_true(names[4] == "Bow" or names[4] == "Gun" or names[4] == "Crossbow")
        end)

        it("should error when group key not found", function()
            local group = randomizer.group({
                type_a = {1, 2, 3}
            })

            local target = {"x"}

            assert.has_error(function()
                group:randomize(target, function() return "nonexistent" end)
            end)
        end)

        it("should error when randomizing with empty list", function()
            local group = randomizer.group({
                a = {1, 2, 3},
                b = {}
            })

            local target = {"item1", "item2"}

            assert.has_error(function()
                group:randomize(target, function(item, idx)
                    return idx == 1 and "a" or "b"
                end)
            end)
        end)
    end)

    describe("ToTable", function()
        it("should convert to plain table of tables", function()
            local group = randomizer.group({
                a = {1, 2},
                b = {3, 4}
            })

            local result = group:toTable()

            assert.are.same({1, 2}, result.a)
            assert.are.same({3, 4}, result.b)
        end)
    end)
end)

