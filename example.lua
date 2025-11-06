-- example lua
-- examples showing typical usage of the randomizer library

local randomizer = require("randomizer")

print("=== Randomizer Examples ===\n")

-- set seed for reproducibility
randomizer.setSeed(42)

print("Basic list randomization")
print("------------------------")

local items = {
	{ id = 1, name = "Item1" },
	{ id = 2, name = "Item2" },
	{ id = 3, name = "Item3" },
	{ id = 4, name = "Item4" },
	{ id = 5, name = "Item5" },
}
local replacements = randomizer.list({ "Apple", "Banana", "Cherry" })

print("Original items:")
for _, item in ipairs(items) do
	print("  " .. item.id .. ": " .. item.name)
end

-- randomize the name field of each item
randomizer.randomize(items, replacements, "name")

print("\nRandomized items:")
for _, item in ipairs(items) do
	print("  " .. item.id .. ": " .. item.name)
end
print()

print("Chaining operations")
print("-------------------")

local numbers = randomizer.list({ 5, 2, 8, 2, 1, 9, 5, 3 })
print("Original:", table.concat(numbers:toTable(), ", "))

local processed = numbers:removeDuplicates():sort():filter(function(x)
	return x > 3
end)

print("After removeDuplicates, sort, filter(>3):", table.concat(processed:toTable(), ", "))
print()

print("Grouped randomization (weapons by type)")
print("----------------------------------------")

-- define our weapons to randomize
local weapons = {
	{ name = "sword_001", type = "melee", tier = 1 },
	{ name = "bow_001", type = "ranged", tier = 1 },
	{ name = "axe_001", type = "melee", tier = 2 },
	{ name = "crossbow_001", type = "ranged", tier = 2 },
	{ name = "dagger_001", type = "melee", tier = 1 },
}

-- create separate pools for melee and ranged weapons
local weaponPools = randomizer.group({
	melee = { "Sword", "Axe", "Mace", "Spear", "Hammer" },
	ranged = { "Bow", "Crossbow", "Rifle", "Pistol", "Slingshot" },
})

print("Weapons before randomization:")
for i, weapon in ipairs(weapons) do
	print(string.format("  %d. %s (type: %s, tier: %d)", i, weapon.name, weapon.type, weapon.tier))
end

-- randomize the name field directly on weapon objects
weaponPools:useToRandomize(weapons, function(weapon)
	return weapon.type
end, "name") -- name is the field to update

print("\nWeapons after randomization:")
for i, weapon in ipairs(weapons) do
	print(string.format("  %d. %s (type: %s, tier: %d)", i, weapon.name, weapon.type, weapon.tier))
end
print()

print("Creating groups with groupBy")
print("-----------------------------")

local characters = {
	{ name = "Warrior", class = "fighter", level = 5 },
	{ name = "Mage", class = "caster", level = 4 },
	{ name = "Paladin", class = "fighter", level = 6 },
	{ name = "Wizard", class = "caster", level = 7 },
	{ name = "Ranger", class = "fighter", level = 5 },
}

-- group characters by class
local characterGroups = randomizer.groupBy(characters, function(char)
	return char.class
end)

print("Characters grouped by class:")
local groupTable = characterGroups:toTable()
for class, chars in pairs(groupTable) do
	print(string.format("  %s:", class))
	for _, char in ipairs(chars) do
		print(string.format("    - %s (level %d)", char.name, char.level))
	end
end
print()

print("Shuffling")
print("---------")

local deck = randomizer.list({ "A", "K", "Q", "J", "10", "9", "8", "7", "6", "5", "4", "3", "2" })
print("Original deck:", table.concat(deck:toTable(), ", "))

local shuffled = deck:shuffle()
-- draw 5 card hand to show it worked
local shuffledTable = shuffled:toTable()
local hand = {}
for i = 1, 5 do
	table.insert(hand, shuffledTable[i])
end
print("First 5 cards:", table.concat(hand, ", "))
print()

print("Filtering groups")
print("----------------")

local itemPools = randomizer.group({
	common = { "Stick", "Stone", "Cloth", "Rope" },
	rare = { "Silver Sword", "Magic Ring", "Potion" },
	legendary = { "Excalibur", "Crown of Kings" },
})

-- filter out items with length less than or equal 5
local filtered = itemPools:filter(function(item)
	return #item > 5
end)

print("Original pools:")
for key, list in pairs(itemPools:toTable()) do
	print(string.format("  %s: %s", key, table.concat(list, ", ")))
end

print("\nFiltered pools (length > 5):")
for key, list in pairs(filtered:toTable()) do
	print(string.format("  %s: %s", key, table.concat(list, ", ")))
end
print()

print("Custom setter functions")
print("-----------------------")

-- items with multiple fields to update
local itemsWithMultiplier = {
	{ id = 1, value = 10, multiplier = 1.0 },
	{ id = 2, value = 20, multiplier = 1.0 },
	{ id = 3, value = 30, multiplier = 1.0 },
}

local valuePool = randomizer.list({ 100, 200, 300 })

print("Items before:")
for _, item in ipairs(itemsWithMultiplier) do
	print(string.format("  ID: %d, Value: %d, Multiplier: %.1f", item.id, item.value, item.multiplier))
end

-- use custom setter function to update multiple fields
valuePool:useToRandomize(itemsWithMultiplier, function(item, newValue)
	item.value = newValue
	item.multiplier = newValue / 100.0
end)

print("\nItems after:")
for _, item in ipairs(itemsWithMultiplier) do
	print(string.format("  ID: %d, Value: %d, Multiplier: %.1f", item.id, item.value, item.multiplier))
end
print()

print("Processing lists")
print("----------------")

local plainList = { 5, 3, 8, 1, 9, 3, 5 }
print("Original plain list:", table.concat(plainList, ", "))

-- create a list object from plain table and chain operations
local processedList = randomizer.list(plainList):removeDuplicates():sort()

print("Remove duplicates and sort:", table.concat(processedList:toTable(), ", "))

local shuffledList = processedList:shuffle()
print("Shuffled:", table.concat(shuffledList:toTable(), ", "))

print("\nDone!")
