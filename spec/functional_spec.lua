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

            -- Start with a list of items with existing rarities
            local items = {
                {id = "item_001", name = "Sword", rarity = "common"},
                {id = "item_002", name = "Shield", rarity = "rare"},
                {id = "item_003", name = "Helmet", rarity = "uncommon"},
                {id = "item_004", name = "Boots", rarity = "legendary"}
            }

            -- Extract existing rarities to create the pool
            local existingRarities = {}
            for i, item in ipairs(items) do
                table.insert(existingRarities, item.rarity)
            end

            -- Create a consumable pool from these rarities
            local rarityPool = randomizer.list(existingRarities)

            -- Randomize the rarities in place using randomizer.randomize with options
            randomizer.randomize(items, rarityPool, "rarity", {consumable = true, regenerate = false})

            -- Verify all items got unique rarities from the original set
            local newRarities = {}
            for _, item in ipairs(items) do
                table.insert(newRarities, item.rarity)
            end
            table.sort(newRarities)
            table.sort(existingRarities)
            assert.are.same(existingRarities, newRarities, "All original rarities should be present exactly once")

            -- Verify other fields are unchanged
            assert.are.equal("Sword", items[1].name)
            assert.are.equal("Shield", items[2].name)
        end)
    end)

    describe("Use Case 2: Grouped Pool Based on Rarity", function()
        it("should randomize damage values based on item rarity where higher rarity means higher damage", function()
            randomizer.setSeed(99)

            -- Start with items that have a rarity and damage
            local items = {
                {name = "Iron Sword", rarity = "common", damage = 10},
                {name = "Steel Axe", rarity = "uncommon", damage = 15},
                {name = "Mithril Blade", rarity = "rare", damage = 20},
                {name = "Dragon Slayer", rarity = "legendary", damage = 25}
            }

            -- Create a reusable, non-consumable grouped pool where damage increases by rarity
            local damageByRarity = randomizer.group({
                common = {8, 10, 12},           -- Low damage
                uncommon = {15, 18, 20},        -- Medium damage
                rare = {25, 28, 30},            -- High damage
                legendary = {35, 40, 45}        -- Very high damage
            }):removeDuplicates()

            -- Randomize damage based on rarity using randomizer.randomize API
            randomizer.randomize(items, damageByRarity, function(item)
                return item.rarity
            end, "damage")

            -- Verify damage values match their rarity tiers
            for _, item in ipairs(items) do
                if item.rarity == "common" then
                    assert.is_true(item.damage >= 8 and item.damage <= 12,
                        "Common items should have low damage")
                elseif item.rarity == "uncommon" then
                    assert.is_true(item.damage >= 15 and item.damage <= 20,
                        "Uncommon items should have medium damage")
                elseif item.rarity == "rare" then
                    assert.is_true(item.damage >= 25 and item.damage <= 30,
                        "Rare items should have high damage")
                elseif item.rarity == "legendary" then
                    assert.is_true(item.damage >= 35 and item.damage <= 45,
                        "Legendary items should have very high damage")
                end
            end

            -- Verify names are unchanged
            assert.are.equal("Iron Sword", items[1].name)
            assert.are.equal("Steel Axe", items[2].name)
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

            -- Randomize health values in place using applyTo (non-consumable = can repeat)
            healthPool:useToRandomize(enemies, "health")

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
            local lootPool = {
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
            }

            -- Randomize loot using randomizer.randomize with plain table (non-consumable = with replacement)
            randomizer.randomize(chests, lootPool, "loot")

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

            -- Characters with starting equipment that needs to be unique per equipment type
            local characters = {
                {name = "Warrior", startingEquipment = "weapon", equipment = "none"},
                {name = "Mage", startingEquipment = "weapon", equipment = "none"},
                {name = "Rogue", startingEquipment = "armor", equipment = "none"},
                {name = "Paladin", startingEquipment = "armor", equipment = "none"}
            }

            -- Create grouped pools for each equipment type
            local equipmentPools = randomizer.group({
                weapon = {"Sword", "Axe"},
                armor = {"Plate Mail", "Chain Mail"}
            })

            -- Use consumable pools to ensure no duplicate equipment within each type
            equipmentPools:useToRandomize(characters, function(char)
                return char.startingEquipment
            end, "equipment", {consumable = true, regenerate = false})

            -- Verify weapon slots have unique weapons
            local weaponEquipment = {}
            local armorEquipment = {}
            for _, char in ipairs(characters) do
                if char.startingEquipment == "weapon" then
                    table.insert(weaponEquipment, char.equipment)
                elseif char.startingEquipment == "armor" then
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

            -- Randomize room content based on difficulty using applyTo
            encounterGroups:useToRandomize(rooms, function(room)
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

    describe("Use Case 7: Two-Stage Randomization with Grouped Pools", function()
        it("should randomize group type first, then randomize values based on new group type", function()
            randomizer.setSeed(789)

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

            -- Stage 1: Randomize the type for each item using randomizer.randomize
            randomizer.randomize(items, typePool, "type")

            -- Verify types are from the pool
            for _, item in ipairs(items) do
                assert.is_true(item.type == "weapon" or item.type == "armor" or item.type == "accessory")
            end

            -- Stage 2: Randomize values based on the NEW type using applyTo
            valueGroups:useToRandomize(items, function(item)
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
end)
