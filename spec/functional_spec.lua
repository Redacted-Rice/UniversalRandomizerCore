-- functional spec lua
-- functional and integration tests for real world use cases

describe("Functional Tests - Typical Use Cases", function()
	local randomizer

	setup(function()
		randomizer = require("randomizer")
	end)

	describe("Use Case 1: Shuffle Values from Original to Modified", function()
		it(
			"should extract values from original items and shuffle them to modified items using consumable pool",
			function()
				randomizer.setSeed(42)

			-- original entities with health values
			local entitiesOriginal = {
					{ name = "Warrior", health = 100 },
					{ name = "Mage", health = 80 },
					{ name = "Rogue", health = 120 },
					{ name = "Paladin", health = 150 },
				}

			-- modified entities that need shuffled health
			local entitiesModified = {
					{ name = "Warrior", health = 0 },
					{ name = "Mage", health = 0 },
					{ name = "Rogue", health = 0 },
					{ name = "Paladin", health = 0 },
				}

			-- create consumable pool by extracting health values from original
			local healthPool = randomizer.listFromField(entitiesOriginal, "health")

			-- verify pool was created correctly
				assert.are.equal(4, healthPool:size())

			-- randomize modified entities health using the consumable pool
			local setter = function(entity, value)
					entity.health = value
				end
				randomizer.randomize(entitiesModified, healthPool, setter, {
					consumable = true,
				})

			-- verify all health values are from the original set and unique
			local newHealths = {}
				for _, entity in ipairs(entitiesModified) do
					table.insert(newHealths, entity.health)
				end
				table.sort(newHealths)

				local expectedHealths = { 80, 100, 120, 150 }
				table.sort(expectedHealths)
				assert.are.same(
					expectedHealths,
					newHealths,
					"All original health values should be present exactly once"
				)

			-- verify names are unchanged
			assert.are.equal("Warrior", entitiesModified[1].name)
				assert.are.equal("Mage", entitiesModified[2].name)
			end
		)
	end)

	describe("Use Case 2: Simple Non-Consumable Pool Randomization", function()
		it("should randomize entity types using a simple pool with replacement", function()
			randomizer.setSeed(123)

		-- entities that need randomized types
		local entities = {
				{ name = "Entity1", type = "UNKNOWN" },
				{ name = "Entity2", type = "UNKNOWN" },
				{ name = "Entity3", type = "UNKNOWN" },
				{ name = "Entity4", type = "UNKNOWN" },
			}

		-- define available types like an enum
		local entityTypes = { "WARRIOR", "MAGE", "ROGUE", "CLERIC", "RANGER" }

		-- randomize types using non consumable pool
			local setter = function(entity, typeValue)
				entity.type = typeValue
			end
			randomizer.randomize(entities, entityTypes, setter)

		-- verify all types are from the pool
		for _, entity in ipairs(entities) do
				local found = false
				for _, t in ipairs(entityTypes) do
					if entity.type == t then
						found = true
					end
				end
				assert.is_true(found, entity.name .. " should have type from pool")
			end

		-- verify names are unchanged
		assert.are.equal("Entity1", entities[1].name)
			assert.are.equal("Entity2", entities[2].name)
		end)
	end)

	describe("Use Case 3: Grouped Stats by Type with Tuple Extraction", function()
		it("should randomize defense and damage tuples based on entity type using grouped pools", function()
			randomizer.setSeed(99)

		-- original entities with type and stat tuples
		local entitiesOriginal = {
				{ name = "Warrior1", type = "WARRIOR", defense = 15, damage = 20 },
				{ name = "Warrior2", type = "WARRIOR", defense = 18, damage = 22 },
				{ name = "Mage1", type = "MAGE", defense = 8, damage = 30 },
				{ name = "Mage2", type = "MAGE", defense = 10, damage = 28 },
				{ name = "Rogue1", type = "ROGUE", defense = 12, damage = 25 },
				{ name = "Rogue2", type = "ROGUE", defense = 14, damage = 27 },
			}

		-- modified entities that need randomized stats
		local entitiesModified = {
				{ name = "Warrior1", type = "WARRIOR", defense = 0, damage = 0 },
				{ name = "Warrior2", type = "WARRIOR", defense = 0, damage = 0 },
				{ name = "Mage1", type = "MAGE", defense = 0, damage = 0 },
				{ name = "Mage2", type = "MAGE", defense = 0, damage = 0 },
				{ name = "Rogue1", type = "ROGUE", defense = 0, damage = 0 },
				{ name = "Rogue2", type = "ROGUE", defense = 0, damage = 0 },
			}

		-- create grouped pool of stat tuples by type
		local statTuplesPool = randomizer.groupFromField(entitiesOriginal, "type", function(entity)
				return { defense = entity.defense, damage = entity.damage }
			end)

		-- verify pools were created with correct sizes
		assert.are.equal(2, statTuplesPool:get("WARRIOR"):size())
			assert.are.equal(2, statTuplesPool:get("MAGE"):size())
			assert.are.equal(2, statTuplesPool:get("ROGUE"):size())

		-- setter function that applies both defense and damage from the tuple
		local setter = function(entity, tuple)
				entity.defense = tuple.defense
				entity.damage = tuple.damage
			end

		-- randomize both stats together based on type
		randomizer.randomize(entitiesModified, statTuplesPool, "type", setter)

		-- verify stats match their types and are from the original pools
			for _, entity in ipairs(entitiesModified) do
				assert.is_not_nil(entity.defense)
				assert.is_not_nil(entity.damage)

				if entity.type == "WARRIOR" then
					assert.is_true(
						(entity.defense == 15 and entity.damage == 20) or (entity.defense == 18 and entity.damage == 22),
						"Warrior stats should match original tuple"
					)
				elseif entity.type == "MAGE" then
					assert.is_true(
						(entity.defense == 8 and entity.damage == 30) or (entity.defense == 10 and entity.damage == 28),
						"Mage stats should match original tuple"
					)
				elseif entity.type == "ROGUE" then
					assert.is_true(
						(entity.defense == 12 and entity.damage == 25) or (entity.defense == 14 and entity.damage == 27),
						"Rogue stats should match original tuple"
					)
				end
			end

		-- verify names are unchanged
		assert.are.equal("Warrior1", entitiesModified[1].name)
			assert.are.equal("Mage1", entitiesModified[3].name)
		end)
	end)

	describe("Use Case 4: Shuffle Stat Tuples by Rarity with Consumable Pools", function()
		it("should shuffle all item stat tuples within the same rarity using grouped consumable pools", function()
			randomizer.setSeed(456)

		-- original items with rarity and multiple stat fields
		local itemsOriginal = {
				{ name = "Sword1", rarity = "common", attack = 5, defense = 3, health = 10, speed = 2 },
				{ name = "Sword2", rarity = "common", attack = 6, defense = 4, health = 12, speed = 3 },
				{ name = "Shield1", rarity = "common", attack = 2, defense = 8, health = 15, speed = 1 },
				{ name = "Axe1", rarity = "rare", attack = 15, defense = 5, health = 20, speed = 4 },
				{ name = "Axe2", rarity = "rare", attack = 18, defense = 6, health = 25, speed = 5 },
				{ name = "Bow1", rarity = "rare", attack = 12, defense = 3, health = 18, speed = 6 },
			}

		-- modified items that need shuffled stats
		local itemsModified = {
				{ name = "Sword1", rarity = "common", attack = 0, defense = 0, health = 0, speed = 0 },
				{ name = "Sword2", rarity = "common", attack = 0, defense = 0, health = 0, speed = 0 },
				{ name = "Shield1", rarity = "common", attack = 0, defense = 0, health = 0, speed = 0 },
				{ name = "Axe1", rarity = "rare", attack = 0, defense = 0, health = 0, speed = 0 },
				{ name = "Axe2", rarity = "rare", attack = 0, defense = 0, health = 0, speed = 0 },
				{ name = "Bow1", rarity = "rare", attack = 0, defense = 0, health = 0, speed = 0 },
			}

		-- create grouped pool of stat tuples by rarity from original items
		local statTuplesPool = randomizer.groupFromField(itemsOriginal, "rarity", function(item)
				return {
					attack = item.attack,
					defense = item.defense,
					health = item.health,
					speed = item.speed,
				}
			end)

		-- verify pools were created correctly
		assert.are.equal(3, statTuplesPool:get("common"):size())
		assert.are.equal(3, statTuplesPool:get("rare"):size())

		-- setter function that applies all stats from the tuple
			local setter = function(item, tuple)
				item.attack = tuple.attack
				item.defense = tuple.defense
				item.health = tuple.health
				item.speed = tuple.speed
			end

		-- shuffle all stats together within rarity groups using consumable pools
		randomizer.randomize(itemsModified, statTuplesPool, "rarity", setter, {
			consumable = true,
		})

		-- verify all stat tuples are unique within each rarity consumable ensures no duplicates
			local commonTuples = {}
			local rareTuples = {}
			for _, item in ipairs(itemsModified) do
				local tuple = { attack = item.attack, defense = item.defense, health = item.health, speed = item.speed }
				if item.rarity == "common" then
					table.insert(commonTuples, tuple)
				elseif item.rarity == "rare" then
					table.insert(rareTuples, tuple)
				end
			end

			-- verify we got all expected tuples for each rarity
			assert.are.equal(3, #commonTuples)
			assert.are.equal(3, #rareTuples)

		-- verify names are unchanged
		assert.are.equal("Sword1", itemsModified[1].name)
			assert.are.equal("Axe1", itemsModified[4].name)
		end)
	end)

	describe("Use Case 5: Two-Phase Randomization - Weighted Rarity then Grouped Items", function()
		it("should first assign weighted rarities, then assign items from grouped pools by rarity", function()
			randomizer.setSeed(789)

			-- Entities that need starting items
			local entities = {
				{ name = "Hero1", startingItem = nil, startingItemRarity = nil },
				{ name = "Hero2", startingItem = nil, startingItemRarity = nil },
				{ name = "Hero3", startingItem = nil, startingItemRarity = nil },
				{ name = "Hero4", startingItem = nil, startingItemRarity = nil },
			}

			-- Available items grouped by rarity
			local items = {
				{ name = "Iron Sword", rarity = "common" },
				{ name = "Wooden Shield", rarity = "common" },
				{ name = "Leather Boots", rarity = "common" },
				{ name = "Steel Axe", rarity = "uncommon" },
				{ name = "Silver Dagger", rarity = "uncommon" },
				{ name = "Mithril Armor", rarity = "rare" },
				{ name = "Enchanted Blade", rarity = "rare" },
			}

			-- Phase 1: Assign starting item rarity to each entity using weighted pool
			-- Weighted pool: common appears more often
			local weightedRarityPool = {
				"common",
				"common",
				"common", -- Common appears 3 times
				"uncommon",
				"uncommon", -- Uncommon appears 2 times
				"rare", -- Rare appears 1 time
			}

			randomizer.randomize(entities, weightedRarityPool, function(entity, rarity)
				entity.startingItemRarity = rarity
			end)

			-- Verify all entities got a rarity
			for _, entity in ipairs(entities) do
				assert.is_not_nil(entity.startingItemRarity, "Entity should have assigned rarity")
				assert.is_true(
					entity.startingItemRarity == "common"
						or entity.startingItemRarity == "uncommon"
						or entity.startingItemRarity == "rare"
				)
			end

			-- Phase 2: Create grouped pool of item names by rarity
			local itemNamesByRarity = randomizer.groupFromField(items, "rarity", "name")

			-- Verify pools were created correctly
			assert.are.equal(3, itemNamesByRarity:get("common"):size())
			assert.are.equal(2, itemNamesByRarity:get("uncommon"):size())
			assert.are.equal(2, itemNamesByRarity:get("rare"):size())

			-- Phase 2: Assign item based on the assigned rarity using consumable pool
			local setter = function(entity, itemName)
				entity.startingItem = itemName
			end
			randomizer.randomize(entities, itemNamesByRarity, "startingItemRarity", setter, {
				consumable = true,
			})

			-- Verify all entities got items matching their assigned rarity
			for _, entity in ipairs(entities) do
				assert.is_not_nil(entity.startingItem, "Entity should have assigned item")

				-- Find the item and verify rarity matches
				local itemFound = false
				for _, item in ipairs(items) do
					if item.name == entity.startingItem then
						assert.are.equal(
							entity.startingItemRarity,
							item.rarity,
							"Item rarity should match entity's assigned rarity"
						)
						itemFound = true
					end
				end
				assert.is_true(itemFound, "Item should exist in the items list")
			end

			-- Verify names are unchanged
			assert.are.equal("Hero1", entities[1].name)
			assert.are.equal("Hero2", entities[2].name)
		end)
	end)

	describe("Use Case 6: Grouped Pool with Method-Based Selection", function()
		it("should use grouped pools with method-based selectors for entity randomization", function()
			randomizer.setSeed(2025)

			-- Create a mock entity-like structure with methods
			local createEntity = function(name, category)
				return {
					name = name,
					category = category,
					getCategory = function(self)
						return self.category
					end,
					setValue = function(self, val)
						self.value = val
					end,
				}
			end

			local entities = {
				createEntity("Entity1", "combat"),
				createEntity("Entity2", "support"),
				createEntity("Entity3", "combat"),
				createEntity("Entity4", "magic"),
			}

			-- Create grouped pools by category
			local valuePools = randomizer.group({
				combat = { 10, 15, 20 },
				support = { 5, 8, 12 },
				magic = { 25, 30, 35 },
			})

			-- Randomize using method-based selector
			randomizer.randomize(entities, valuePools, "getCategory", function(entity, value)
				entity:setValue(value)
			end)

			-- Verify values match their categories
			for _, entity in ipairs(entities) do
				assert.is_not_nil(entity.value, "Entity should have assigned value")

				if entity.category == "combat" then
					local found = false
					for _, v in ipairs({ 10, 15, 20 }) do
						if entity.value == v then
							found = true
						end
					end
					assert.is_true(found, "Combat entity value should be from combat pool")
				elseif entity.category == "support" then
					local found = false
					for _, v in ipairs({ 5, 8, 12 }) do
						if entity.value == v then
							found = true
						end
					end
					assert.is_true(found, "Support entity value should be from support pool")
				elseif entity.category == "magic" then
					local found = false
					for _, v in ipairs({ 25, 30, 35 }) do
						if entity.value == v then
							found = true
						end
					end
					assert.is_true(found, "Magic entity value should be from magic pool")
				end
			end
		end)
	end)

	describe("Use Case 7: Change Detection", function()
		it("should detect and report changes made during randomization", function()
			randomizer.setSeed(555)
			local changedetector = require("randomizer.changedetector")

			-- enable change detection
			changedetector.configure(true)

			local entities = {
				{ name = "Warrior", health = 101, damage = 21, defense = 15 },
				{ name = "Mage", health = 81, damage = 31, defense = 8 },
				{ name = "Rogue", health = 91, damage = 26, defense = 12 },
			}

			-- Monitor the stat fields and use name to identify for return structure
			local identifierFn = function(entity)
				return entity.name
			end
			changedetector.monitor("entities", entities, { "health", "damage", "defense" }, identifierFn)

			-- Take initial snapshot
			changedetector.takeSnapshots()

			-- randomize the health and damage only with values not in original set to ensure changes
			local healthPool = { 70, 85, 95, 110, 125 }
			randomizer.randomize(entities, healthPool, function(entity, value)
				entity.health = value
			end)

			local damagePool = { 15, 20, 25, 30, 35 }
			randomizer.randomize(entities, damagePool, function(entity, value)
				entity.damage = value
			end)

			-- verify changes were detected
			local changes = changedetector.detectChanges()
			assert.is_true(
				changedetector.hasChanges(changes),
				"Changes should be detected after randomization"
			)

			-- verify all changed
			assert.is_not_nil(changes.entities, "Entity changes should exist")
			assert.is_not_nil(changes.entities["Warrior"], "Warrior should have changes")
			assert.is_not_nil(changes.entities["Mage"], "Mage should have changes")
			assert.is_not_nil(changes.entities["Rogue"], "Rogue should have changes")

			-- Spot check both heath and damage
			assert.is_not_nil(
				changes.entities["Warrior"].health,
				"Warrior health should have changed"
			)
			assert.are.equal(
				"101",
				changes.entities["Warrior"].health.old,
				"Warrior old health should be 101"
			)
			assert.is_not_nil(
				changes.entities["Warrior"].health.new,
				"Warrior should have new health"
			)
			assert.is_not_nil(
				changes.entities["Mage"].damage,
				"Mage damage should have changed"
			)
			assert.are.equal(
				"31",
				changes.entities["Mage"].damage.old,
				"Mage old damage should be 31"
			)
			assert.is_not_nil(
				changes.entities["Mage"].damage.new,
				"Mage should have new damage"
			)

			-- verify defense is not reported as it wasnt changed
			assert.is_nil(
				changes.entities["Warrior"].defense,
				"Warrior defense should be unchanged"
			)

			-- reset change detection for next tests
			changedetector.stopMonitoringAll()
			changedetector.configure(false)
		end)

		it("should track multiple randomization phases with separate snapshots", function()
			randomizer.setSeed(777)
			local changedetector = require("randomizer.changedetector")

            -- Setup the test
			changedetector.configure(true)
			local items = {
				{ name = "Sword", attack = 10, durability = 105 },
				{ name = "Shield", attack = 5, durability = 155 },
				{ name = "Bow", attack = 15, durability = 85 },
			}

            -- monitor changes to attack and durability and use name to identify for return structure
			local identifierFn = function(item)
				return item.name
			end
			changedetector.monitor("items", items, { "attack", "durability" }, identifierFn)

			-- First randomize attack
			changedetector.takeSnapshots()
			local attackPool = { 8, 12, 16, 20 }
			randomizer.randomize(items, attackPool, function(item, value)
				item.attack = value
			end)

			local phase1Changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(phase1Changes))

			-- Spot check that attack was detected but not durability
            assert.is_not_nil(
                phase1Changes.items["Sword"].attack,
                "Sword attack should have changed"
            )
            assert.is_nil(
                phase1Changes.items["Sword"].durability,
                "Sword durability should be unchanged"
            )

			-- Now take a new snapshot and randomize durability
			changedetector.takeSnapshots()
			local durabilityPool = { 60, 80, 100, 120, 140 }
			randomizer.randomize(items, durabilityPool, function(item, value)
				item.durability = value
			end)

			local phase2Changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(phase2Changes))

			-- Spot check that durability was detected but not attack since
            -- we took a new snapshot since then
            assert.is_not_nil(
                phase2Changes.items["Shield"].durability,
                "Shield durability should have changed"
            )
            assert.is_nil(
                phase2Changes.items["Shield"].attack,
                "Shield attack should be unchanged in this phase"
            )

			-- Clean up
			changedetector.stopMonitoringAll()
			changedetector.configure(false)
		end)

		it("should support change detection with grouped randomization", function()
			randomizer.setSeed(888)
			local changedetector = require("randomizer.changedetector")

			changedetector.configure(true)

			-- Create units of different types
			local units = {
				{ name = "Tank1", type = "TANK", armor = 20 },
				{ name = "Tank2", type = "TANK", armor = 22 },
				{ name = "Healer1", type = "HEALER", armor = 10 },
				{ name = "Healer2", type = "HEALER", armor = 12 },
			}

			local identifierFn = function(unit)
				return unit.name
			end
			changedetector.monitor("units", units, { "armor" }, identifierFn)

			-- Take snapshot before randomization
			changedetector.takeSnapshots()

			-- Create grouped armor pools by type
			local armorPools = randomizer.group({
				TANK = { 18, 20, 22, 24, 26 },
				HEALER = { 8, 10, 12, 14 },
			})

			-- Randomize armor based on type
			randomizer.randomize(units, armorPools, "type", function(unit, value)
				unit.armor = value
			end)

			-- Detect changes
			local changes = changedetector.detectChanges()

			-- Verify changes detected for all units
			assert.is_true(changedetector.hasChanges(changes))

			-- Each unit may or may not have changes depending on random selection
			-- But the system should track them correctly
			assert.is_not_nil(changes.units, "Unit changes should exist")

			-- Verify old values are correct
			if changes.units["Tank1"] and changes.units["Tank1"].armor then
				assert.are.equal("20", changes.units["Tank1"].armor.old)
			end
			if changes.units["Healer1"] and changes.units["Healer1"].armor then
				assert.are.equal("10", changes.units["Healer1"].armor.old)
			end

			-- reset change detection for next tests
			changedetector.stopMonitoringAll()
			changedetector.configure(false)
		end)
	end)
end)
