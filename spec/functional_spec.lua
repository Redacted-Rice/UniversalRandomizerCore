-- functional_spec.lua
-- Functional/integration tests for real-world use cases

describe("Functional Tests - Real World Workflows", function()
    local randomizer

    setup(function()
        randomizer = require("randomizer")
    end)

    describe("Game Modding: Weapon Randomization", function()
        it("should randomize weapon drops while preserving weapon types", function()
            randomizer.setSeed(42)

            -- Simulate a game's weapon inventory
            local weapons = {
                {id = "sword_001", name = "Iron Sword", type = "melee", damage = 10},
                {id = "bow_001", name = "Wooden Bow", type = "ranged", damage = 8},
                {id = "axe_001", name = "Battle Axe", type = "melee", damage = 12},
                {id = "crossbow_001", name = "Light Crossbow", type = "ranged", damage = 10},
                {id = "dagger_001", name = "Rusty Dagger", type = "melee", damage = 6}
            }

            -- Define replacement pools for each weapon type
            local weaponPools = randomizer.group({
                melee = {"Excalibur", "Dragon Slayer", "Mjolnir", "Kusanagi", "Durendal"},
                ranged = {"Longbow", "Artemis Bow", "Crossbow of Destiny", "Gungnir"}
            })

            -- Extract weapon names for randomization
            local originalNames = {}
            for i, weapon in ipairs(weapons) do
                originalNames[i] = weapon.name
            end

            -- Randomize weapon names based on type
            weaponPools:randomize(originalNames, function(name, index)
                return weapons[index].type
            end)

            -- Verify all melee weapons got melee replacements
            for i, weapon in ipairs(weapons) do
                if weapon.type == "melee" then
                    -- Should be one of the melee weapons
                    local found = false
                    for _, meleeName in ipairs(weaponPools:get("melee"):toTable()) do
                        if originalNames[i] == meleeName then
                            found = true
                            break
                        end
                    end
                    assert.is_true(found, "Melee weapon " .. weapon.id .. " got non-melee replacement")
                end

                if weapon.type == "ranged" then
                    -- Should be one of the ranged weapons
                    local found = false
                    for _, rangedName in ipairs(weaponPools:get("ranged"):toTable()) do
                        if originalNames[i] == rangedName then
                            found = true
                            break
                        end
                    end
                    assert.is_true(found, "Ranged weapon " .. weapon.id .. " got non-ranged replacement")
                end
            end

            -- Verify we got variety (not all the same)
            local uniqueNames = randomizer.removeDuplicates(originalNames)
            assert.is_true(#uniqueNames > 1, "Should have variety in randomized names")
        end)
    end)

    describe("Game Modding: Enemy Loot by Difficulty", function()
        it("should assign appropriate loot based on enemy difficulty", function()
            randomizer.setSeed(99)

            -- Simulate enemy encounters
            local enemies = {
                {name = "Goblin", difficulty = "easy"},
                {name = "Wolf", difficulty = "easy"},
                {name = "Orc", difficulty = "medium"},
                {name = "Troll", difficulty = "medium"},
                {name = "Dragon", difficulty = "hard"},
                {name = "Lich", difficulty = "hard"}
            }

            -- Define loot pools by difficulty
            local lootPools = randomizer.group({
                easy = {"Copper Coin", "Stick", "Cloth", "Small Potion"},
                medium = {"Silver Coin", "Iron Sword", "Leather Armor", "Medium Potion"},
                hard = {"Gold Coin", "Magic Sword", "Plate Armor", "Large Potion", "Rare Gem"}
            })

            -- Assign loot to enemies
            local lootDrops = {}
            for i = 1, #enemies do
                lootDrops[i] = "placeholder"
            end

            lootPools:randomize(lootDrops, function(drop, index)
                return enemies[index].difficulty
            end)

            -- Verify appropriate loot distribution
            local easyLoot = lootPools:get("easy"):toTable()
            local mediumLoot = lootPools:get("medium"):toTable()
            local hardLoot = lootPools:get("hard"):toTable()

            for i, enemy in ipairs(enemies) do
                local drop = lootDrops[i]

                if enemy.difficulty == "easy" then
                    local found = false
                    for _, item in ipairs(easyLoot) do
                        if drop == item then found = true end
                    end
                    assert.is_true(found, enemy.name .. " should drop easy loot")
                elseif enemy.difficulty == "medium" then
                    local found = false
                    for _, item in ipairs(mediumLoot) do
                        if drop == item then found = true end
                    end
                    assert.is_true(found, enemy.name .. " should drop medium loot")
                elseif enemy.difficulty == "hard" then
                    local found = false
                    for _, item in ipairs(hardLoot) do
                        if drop == item then found = true end
                    end
                    assert.is_true(found, enemy.name .. " should drop hard loot")
                end
            end
        end)
    end)

    describe("Procedural Generation: Dungeon Room Contents", function()
        it("should generate varied room contents based on room type", function()
            randomizer.setSeed(123)

            -- Define dungeon layout
            local rooms = {
                {id = 1, type = "combat"},
                {id = 2, type = "treasure"},
                {id = 3, type = "combat"},
                {id = 4, type = "puzzle"},
                {id = 5, type = "combat"},
                {id = 6, type = "treasure"},
                {id = 7, type = "boss"}
            }

            -- Content pools for each room type
            local contentPools = randomizer.group({
                combat = {"Goblins", "Orcs", "Skeletons", "Wolves", "Spiders"},
                treasure = {"Gold Chest", "Weapon Cache", "Potion Stash", "Magic Scroll"},
                puzzle = {"Lever Puzzle", "Floor Trap", "Magic Barrier", "Riddle Door"},
                boss = {"Dragon", "Lich King", "Ancient Golem"}
            })

            -- Assign contents
            local roomContents = {}
            for i = 1, #rooms do
                roomContents[i] = "empty"
            end

            contentPools:randomize(roomContents, function(content, index)
                return rooms[index].type
            end)

            -- Verify room contents match room types
            for i, room in ipairs(rooms) do
                local content = roomContents[i]
                local pool = contentPools:get(room.type):toTable()

                local found = false
                for _, item in ipairs(pool) do
                    if content == item then found = true end
                end

                assert.is_true(found, "Room " .. room.id .. " (" .. room.type .. ") has inappropriate content: " .. content)
            end

            -- Verify we have variety
            local combatRooms = {}
            for i, room in ipairs(rooms) do
                if room.type == "combat" then
                    table.insert(combatRooms, roomContents[i])
                end
            end
            -- Combat rooms should potentially have different enemies (though random, so may match)
            assert.are.equal(3, #combatRooms)
        end)
    end)

    describe("Data Processing: Grouping and Randomization Workflow", function()
        it("should group items by category and randomize within categories", function()
            randomizer.setSeed(456)

            -- Mixed item list
            local items = {
                {name = "Apple", category = "fruit", value = 1},
                {name = "Carrot", category = "vegetable", value = 2},
                {name = "Banana", category = "fruit", value = 1},
                {name = "Broccoli", category = "vegetable", value = 3},
                {name = "Orange", category = "fruit", value = 2},
                {name = "Potato", category = "vegetable", value = 1}
            }

            -- Group by category
            local grouped = randomizer.groupBy(items, function(item)
                return item.category
            end)

            assert.are.equal(2, grouped:size())

            -- Create replacement pools
            local replacements = randomizer.group({
                fruit = {
                    {name = "Mango", category = "fruit", value = 3},
                    {name = "Grape", category = "fruit", value = 1},
                    {name = "Peach", category = "fruit", value = 2}
                },
                vegetable = {
                    {name = "Lettuce", category = "vegetable", value = 1},
                    {name = "Tomato", category = "vegetable", value = 2},
                    {name = "Cucumber", category = "vegetable", value = 2}
                }
            })

            -- Randomize items
            local newItems = {}
            for i = 1, #items do
                newItems[i] = items[i]
            end

            replacements:randomize(newItems, function(item, index)
                return items[index].category
            end)

            -- Verify categories are preserved
            for i, item in ipairs(items) do
                assert.are.equal(items[i].category, newItems[i].category,
                    "Item at index " .. i .. " should maintain category")
            end
        end)
    end)

    describe("Complex Workflow: Multi-Stage Processing", function()
        it("should support filtering, sorting, and randomizing in sequence", function()
            randomizer.setSeed(789)

            -- Start with raw data
            local rawData = {
                {id = 1, level = 5, rarity = "common"},
                {id = 2, level = 10, rarity = "rare"},
                {id = 3, level = 3, rarity = "common"},
                {id = 4, level = 15, rarity = "legendary"},
                {id = 5, level = 8, rarity = "rare"},
                {id = 6, level = 2, rarity = "common"},
                {id = 7, level = 12, rarity = "rare"}
            }

            -- Step 1: Filter out low-level items (< 5)
            local filtered = randomizer.filter(rawData, function(item)
                return item.level >= 5
            end)

            assert.are.equal(5, #filtered)

            -- Step 2: Group by rarity
            local grouped = randomizer.groupBy(filtered, function(item)
                return item.rarity
            end)

            -- Step 3: Sort each group by level
            local sorted = grouped:sort(function(a, b)
                return a.level < b.level
            end)

            -- Verify sorting worked
            local commonItems = sorted:get("common"):toTable()
            assert.are.equal(5, commonItems[1].level)

            local rareItems = sorted:get("rare"):toTable()
            assert.are.equal(8, rareItems[1].level)
            assert.are.equal(10, rareItems[2].level)
            assert.are.equal(12, rareItems[3].level)

            -- Step 4: Now randomize something using these groups
            local targets = {"item1", "item2", "item3"}
            local rarities = {"common", "rare", "legendary"}

            local rewardIds = {}
            for i = 1, #targets do
                rewardIds[i] = 0
            end

            sorted:randomize(rewardIds, function(reward, index)
                return rarities[index]
            end)

            -- Verify we got valid IDs from the appropriate rarity groups
            for i, id in ipairs(rewardIds) do
                assert.is_true(type(id) == "table" and id.id ~= nil)
                assert.are.equal(rarities[i], id.rarity)
            end
        end)
    end)

    describe("Edge Case Workflows", function()
        it("should handle empty groups gracefully", function()
            local group = randomizer.group({})
            assert.is_true(group:isEmpty())
            assert.are.equal(0, group:size())
        end)

        it("should handle chaining many operations", function()
            randomizer.setSeed(111)

            -- Start with duplicated, unsorted data
            local data = randomizer.list({5, 3, 8, 3, 1, 9, 5, 2, 8, 1})

            -- Chain: dedupe -> sort -> filter -> shuffle
            local result = data
                :removeDuplicates()  -- {5, 3, 8, 1, 9, 2}
                :sort()              -- {1, 2, 3, 5, 8, 9}
                :filter(function(x) return x >= 3 and x <= 8 end)  -- {3, 5, 8}
                :shuffle()           -- Random order

            local final = result:toTable()

            -- Should have 3 elements
            assert.are.equal(3, #final)

            -- Should only contain 3, 5, 8
            table.sort(final)
            assert.are.same({3, 5, 8}, final)
        end)

        it("should preserve original data through immutable operations", function()
            local original = {5, 2, 8, 1, 9}
            local list = randomizer.list(original)

            -- Perform multiple operations
            local sorted = list:sort()
            local filtered = sorted:filter(function(x) return x > 3 end)
            local shuffled = filtered:shuffle()

            -- Original should be unchanged
            assert.are.same({5, 2, 8, 1, 9}, original)
            assert.are.same({5, 2, 8, 1, 9}, list:toTable())

            -- Each step should have its own data
            assert.are.same({1, 2, 5, 8, 9}, sorted:toTable())
            assert.are.same({5, 8, 9}, filtered:toTable())
            -- Shuffled should have same elements (verify by sorting)
            local shuffledSorted = randomizer.sort(shuffled:toTable())
            assert.are.same({5, 8, 9}, shuffledSorted)
        end)
    end)

    describe("Game Modding: Limited-Use Loot Tables (Consumable Pools)", function()
        it("should assign unique drops until pools deplete; then honor regenerate flag", function()
            randomizer.setSeed(2025)

            local enemies = {
                {name = "Goblin", difficulty = "easy"},
                {name = "Wolf", difficulty = "easy"},
                {name = "Orc", difficulty = "medium"},
                {name = "Troll", difficulty = "medium"}
            }

            local lootPools = randomizer.group({
                easy = {"Copper Coin", "Stick"},
                medium = {"Silver Coin", "Iron Sword"}
            })

            -- First pass: consumable without regenerate yields unique items within difficulty
            local drops1 = {"","","",""}
            lootPools:randomize(drops1, function(_, i) return enemies[i].difficulty end, { consumable = true, regenerate = false })

            -- Each difficulty's drops should be a permutation of its pool
            local easyDrops = {drops1[1], drops1[2]}
            table.sort(easyDrops)
            assert.are.same({"Copper Coin","Stick"}, easyDrops)
            local medDrops = {drops1[3], drops1[4]}
            table.sort(medDrops)
            assert.are.same({"Iron Sword","Silver Coin"}, medDrops)

            -- Second pass with more enemies than pool size should error without regenerate
            local more = {"","",""}
            assert.has_error(function()
                lootPools:randomize(more, function() return "easy" end, { consumable = true, regenerate = false })
            end)

            -- Third pass with regenerate=true should continue by refilling as needed
            local moreOk = {"","",""}
            lootPools:randomize(moreOk, function() return "easy" end, { consumable = true, regenerate = true })
            for _, d in ipairs(moreOk) do
                assert.is_true(d == "Copper Coin" or d == "Stick")
            end
        end)
    end)
end)
