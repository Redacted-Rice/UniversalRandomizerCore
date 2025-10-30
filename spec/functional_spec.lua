-- functional_spec.lua
-- Functional/integration tests for real-world use cases

describe("Functional Tests - Typical Use Cases", function()
    local randomizer

    setup(function()
        randomizer = require("randomizer")
    end)

    describe("Use Case 1: Consumable Pool from Existing Values", function()
        it("should create a consumable pool from existing object values and randomize in place", function()
            randomizer.setSeed(42)

            -- Start with a list of items with existing IDs
            local items = {
                {id = "item_001", name = "Sword", rarity = "common"},
                {id = "item_002", name = "Shield", rarity = "rare"},
                {id = "item_003", name = "Helmet", rarity = "uncommon"},
                {id = "item_004", name = "Boots", rarity = "common"}
            }

            -- Extract existing IDs to create the pool
            local existingIds = {}
            for i, item in ipairs(items) do
                table.insert(existingIds, item.id)
            end

            -- Create a consumable pool from these IDs
            local idPool = randomizer.list(existingIds)

            -- Randomize the IDs in place, consuming from the pool (no regenerate means each ID used once)
            idPool:randomize(items, "id", {consumable = true, regenerate = false})

            -- Verify all items got unique IDs from the original set
            local newIds = {}
            for _, item in ipairs(items) do
                table.insert(newIds, item.id)
            end
            table.sort(newIds)
            table.sort(existingIds)
            assert.are.same(existingIds, newIds, "All original IDs should be present exactly once")

            -- Verify other fields are unchanged
            assert.are.equal("Sword", items[1].name)
            assert.are.equal("Shield", items[2].name)
        end)
    end)

    describe("Use Case 2: Two-Stage Randomization with Grouped Pools", function()
        it("should randomize group type first, then randomize values based on new group type", function()
            randomizer.setSeed(99)

            -- Start with items that have a type and value
            local items = {
                {name = "Item1", type = "weapon", damage = 10},
                {name = "Item2", type = "armor", defense = 5},
                {name = "Item3", type = "weapon", damage = 15},
                {name = "Item4", type = "armor", defense = 8}
            }

            -- Create a reusable pool of types (no duplicates)
            local typePool = randomizer.list({"weapon", "armor", "accessory"}):removeDuplicates()

            -- Create a reusable, non-consumable grouped pool of values
            local valueGroups = randomizer.group({
                weapon = {12, 18, 25, 30},      -- damage values
                armor = {10, 15, 20, 25},        -- defense values
                accessory = {5, 8, 12, 15}       -- bonus values
            }):removeDuplicates()

            -- Stage 1: Randomize the type for each item
            typePool:randomize(items, "type")

            -- Verify types are from the pool
            for _, item in ipairs(items) do
                assert.is_true(item.type == "weapon" or item.type == "armor" or item.type == "accessory")
            end

            -- Stage 2: Randomize values based on the NEW type
            valueGroups:randomize(items, function(item)
                return item.type
            end, function(item, value)
                -- Set the appropriate stat based on type
                if item.type == "weapon" then
                    item.damage = value
                elseif item.type == "armor" then
                    item.defense = value
                elseif item.type == "accessory" then
                    item.bonus = value
                end
            end)

            -- Verify values match their types
            for _, item in ipairs(items) do
                if item.type == "weapon" then
                    assert.is_not_nil(item.damage)
                    local found = false
                    for _, v in ipairs({12, 18, 25, 30}) do
                        if item.damage == v then found = true end
                    end
                    assert.is_true(found, "Weapon damage should be from weapon pool")
                elseif item.type == "armor" then
                    assert.is_not_nil(item.defense)
                    local found = false
                    for _, v in ipairs({10, 15, 20, 25}) do
                        if item.defense == v then found = true end
                    end
                    assert.is_true(found, "Armor defense should be from armor pool")
                elseif item.type == "accessory" then
                    assert.is_not_nil(item.bonus)
                    local found = false
                    for _, v in ipairs({5, 8, 12, 15}) do
                        if item.bonus == v then found = true end
                    end
                    assert.is_true(found, "Accessory bonus should be from accessory pool")
                end
            end
        end)
    end)

    describe("Use Case 3: Uniform Non-Consumable Pool", function()
        it("should randomize parameters using a uniform pool with replacement", function()
            randomizer.setSeed(123)

            -- Start with enemies that need randomized health
            local enemies = {
                {name = "Goblin", health = 10},
                {name = "Orc", health = 20},
                {name = "Troll", health = 30},
                {name = "Dragon", health = 40}
            }

            -- Create a uniform pool where each value has equal probability
            local healthPool = randomizer.list({50, 75, 100, 125, 150})

            -- Randomize health values in place (non-consumable = can repeat)
            healthPool:randomize(enemies, "health")

            -- Verify all health values are from the pool
            for _, enemy in ipairs(enemies) do
                local found = false
                for _, h in ipairs({50, 75, 100, 125, 150}) do
                    if enemy.health == h then found = true end
                end
                assert.is_true(found, enemy.name .. " should have health from pool")
            end

            -- Names should be unchanged
            assert.are.equal("Goblin", enemies[1].name)
            assert.are.equal("Orc", enemies[2].name)
        end)
    end)

    describe("Use Case 4: Weighted Non-Consumable Pool", function()
        it("should randomize using a weighted pool where duplicates increase probability", function()
            randomizer.setSeed(456)

            -- Start with treasure chests
            local chests = {
                {id = 1, loot = "nothing"},
                {id = 2, loot = "nothing"},
                {id = 3, loot = "nothing"},
                {id = 4, loot = "nothing"},
                {id = 5, loot = "nothing"},
                {id = 6, loot = "nothing"},
                {id = 7, loot = "nothing"},
                {id = 8, loot = "nothing"}
            }

            -- Create a weighted pool by adding duplicates
            -- Common items appear more often, rare items appear less
            local lootPool = randomizer.list({
                "Gold Coin",      -- Common (appears 5 times)
                "Gold Coin",
                "Gold Coin",
                "Gold Coin",
                "Gold Coin",
                "Silver Coin",    -- Uncommon (appears 3 times)
                "Silver Coin",
                "Silver Coin",
                "Magic Gem",      -- Rare (appears 1 time)
                "Legendary Sword" -- Legendary (appears 1 time)
            })

            -- Randomize loot (non-consumable = with replacement)
            lootPool:randomize(chests, "loot")

            -- Count occurrences
            local counts = {
                ["Gold Coin"] = 0,
                ["Silver Coin"] = 0,
                ["Magic Gem"] = 0,
                ["Legendary Sword"] = 0
            }

            for _, chest in ipairs(chests) do
                counts[chest.loot] = counts[chest.loot] + 1
            end

            -- Verify all loot is from the pool
            for _, chest in ipairs(chests) do
                assert.is_not_nil(counts[chest.loot], "Loot should be from pool")
            end

            -- With weighted pool, we expect more common items on average
            -- (We can't guarantee specific distributions with only 8 samples,
            -- but we verify the mechanism works)
            local totalItems = 0
            for _, count in pairs(counts) do
                totalItems = totalItems + count
            end
            assert.are.equal(8, totalItems, "All chests should have loot")
        end)
    end)

    describe("Use Case 5: Grouped Consumable Pools", function()
        it("should use consumable pools per group for unique assignments", function()
            randomizer.setSeed(789)

            -- Character slots that need unique equipment per slot type
            local characters = {
                {name = "Warrior", slotType = "weapon", equipment = "none"},
                {name = "Mage", slotType = "weapon", equipment = "none"},
                {name = "Rogue", slotType = "armor", equipment = "none"},
                {name = "Paladin", slotType = "armor", equipment = "none"}
            }

            -- Create grouped pools for each slot type
            local equipmentPools = randomizer.group({
                weapon = {"Sword", "Axe"},
                armor = {"Plate Mail", "Chain Mail"}
            })

            -- Use consumable pools to ensure no duplicate equipment within each type
            equipmentPools:randomize(characters, function(char)
                return char.slotType
            end, "equipment", {consumable = true, regenerate = false})

            -- Verify weapon slots have unique weapons
            local weaponEquipment = {}
            local armorEquipment = {}
            for _, char in ipairs(characters) do
                if char.slotType == "weapon" then
                    table.insert(weaponEquipment, char.equipment)
                elseif char.slotType == "armor" then
                    table.insert(armorEquipment, char.equipment)
                end
            end

            table.sort(weaponEquipment)
            table.sort(armorEquipment)
            assert.are.same({"Axe", "Sword"}, weaponEquipment, "Weapons should be unique")
            assert.are.same({"Chain Mail", "Plate Mail"}, armorEquipment, "Armor should be unique")
        end)
    end)

    describe("Use Case 6: Procedural Generation with Filtered Pools", function()
        it("should filter and randomize for procedural content generation", function()
            randomizer.setSeed(2025)

            -- Dungeon rooms that need content
            local rooms = {
                {id = 1, difficulty = "easy", content = "empty"},
                {id = 2, difficulty = "hard", content = "empty"},
                {id = 3, difficulty = "medium", content = "empty"},
                {id = 4, difficulty = "easy", content = "empty"}
            }

            -- Start with all possible encounters and filter/group by difficulty
            local allEncounters = {
                {name = "Rat", difficulty = "easy"},
                {name = "Goblin", difficulty = "easy"},
                {name = "Wolf", difficulty = "medium"},
                {name = "Orc", difficulty = "medium"},
                {name = "Dragon", difficulty = "hard"},
                {name = "Demon", difficulty = "hard"}
            }

            -- Group encounters by difficulty
            local encounterGroups = randomizer.groupBy(allEncounters, function(encounter)
                return encounter.difficulty
            end)

            -- Randomize room content based on difficulty
            encounterGroups:randomize(rooms, function(room)
                return room.difficulty
            end, function(room, encounter)
                room.content = encounter.name
            end)

            -- Verify appropriate difficulty matching
            for _, room in ipairs(rooms) do
                if room.difficulty == "easy" then
                    assert.is_true(room.content == "Rat" or room.content == "Goblin")
                elseif room.difficulty == "medium" then
                    assert.is_true(room.content == "Wolf" or room.content == "Orc")
                elseif room.difficulty == "hard" then
                    assert.is_true(room.content == "Dragon" or room.content == "Demon")
                end
            end
        end)
    end)
end)
