-- example.lua
-- Demonstration of the randomizer library features

local randomizer = require("randomizer")

print("=== Randomizer Library Examples ===\n")

-- Set seed for reproducibility
randomizer.setSeed(12345)

-- Example 1: Simple List Randomization
print("Example 1: Simple List Randomization")
print("-------------------------------------")

local items = {"Item1", "Item2", "Item3", "Item4", "Item5"}
local replacements = randomizer.list({"Apple", "Banana", "Cherry"})

print("Original items:", table.concat(items, ", "))
print("Replacement pool:", table.concat(replacements:toTable(), ", "))

local randomized = randomizer.randomize(items, replacements)
print("Randomized items:", table.concat(randomized, ", "))
print()

-- Example 2: Chainable List Operations
print("Example 2: Chainable List Operations")
print("-------------------------------------")

local numbers = randomizer.list({5, 2, 8, 2, 1, 9, 5, 3})
print("Original:", table.concat(numbers:toTable(), ", "))

local processed = numbers
    :removeDuplicates()
    :sort()
    :filter(function(x) return x > 3 end)

print("After removeDuplicates, sort, filter(>3):", table.concat(processed:toTable(), ", "))
print()

-- Example 3: Weapon Randomization with Grouped Pools (In-Place)
print("Example 3: Weapon Randomization (Grouped, In-Place)")
print("-----------------------------------------------------")

-- Define our weapons to randomize
local weapons = {
    {name = "sword_001", type = "melee", tier = 1},
    {name = "bow_001", type = "ranged", tier = 1},
    {name = "axe_001", type = "melee", tier = 2},
    {name = "crossbow_001", type = "ranged", tier = 2},
    {name = "dagger_001", type = "melee", tier = 1},
}

-- Create separate pools for melee and ranged weapons
local weaponPools = randomizer.group({
    melee = {"Sword", "Axe", "Mace", "Spear", "Hammer"},
    ranged = {"Bow", "Crossbow", "Rifle", "Pistol", "Slingshot"}
})

print("Weapons before randomization:")
for i, weapon in ipairs(weapons) do
    print(string.format("  %d. %s (type: %s, tier: %d)",
        i, weapon.name, weapon.type, weapon.tier))
end

-- Randomize the 'name' field directly on weapon objects
weaponPools:useToRandomize(weapons, function(weapon)
    return weapon.type
end, "name")  -- "name" is the field to update

print("\nWeapons after randomization:")
for i, weapon in ipairs(weapons) do
    print(string.format("  %d. %s (type: %s, tier: %d)",
        i, weapon.name, weapon.type, weapon.tier))
end
print()

-- Example 4: Creating Groups from Lists
print("Example 4: Creating Groups from Lists (groupBy)")
print("------------------------------------------------")

local characters = {
    {name = "Warrior", class = "fighter", level = 5},
    {name = "Mage", class = "caster", level = 4},
    {name = "Paladin", class = "fighter", level = 6},
    {name = "Wizard", class = "caster", level = 7},
    {name = "Ranger", class = "fighter", level = 5},
}

-- Group characters by class
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

-- Example 5: Shuffling and Selecting
print("Example 5: Shuffling and Selecting")
print("-----------------------------------")

local deck = randomizer.list({"A♠", "K♠", "Q♠", "J♠", "10♠", "9♠", "8♠", "7♠"})
print("Original deck:", table.concat(deck:toTable(), ", "))

local shuffled = deck:shuffle()
print("Shuffled deck:", table.concat(shuffled:toTable(), ", "))

local hand = shuffled:select({1, 2, 3, 4, 5})
print("First 5 cards:", table.concat(hand:toTable(), ", "))
print()

-- Example 6: Filtering Groups
print("Example 6: Filtering Groups")
print("----------------------------")

local itemPools = randomizer.group({
    common = {"Stick", "Stone", "Cloth", "Rope"},
    rare = {"Silver Sword", "Magic Ring", "Potion"},
    legendary = {"Excalibur", "Crown of Kings"}
})

-- Filter out items with length <= 5
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

-- Example 7: In-Place Randomization with Custom Setter
print("Example 7: In-Place Randomization with Custom Setter")
print("------------------------------------------------------")

-- Items with multiple fields to update
local items = {
    {id = 1, value = 10, multiplier = 1.0},
    {id = 2, value = 20, multiplier = 1.0},
    {id = 3, value = 30, multiplier = 1.0}
}

local valuePool = randomizer.list({100, 200, 300})

print("Items before:")
for _, item in ipairs(items) do
    print(string.format("  ID: %d, Value: %d, Multiplier: %.1f", item.id, item.value, item.multiplier))
end

-- Use custom setter function to update multiple fields
valuePool:useToRandomize(items, function(item, newValue, index)
    item.value = newValue
    item.multiplier = newValue / 100.0
end)

print("\nItems after:")
for _, item in ipairs(items) do
    print(string.format("  ID: %d, Value: %d, Multiplier: %.1f", item.id, item.value, item.multiplier))
end
print()

-- Example 8: Using Standalone Functions
print("Example 8: Using Standalone Functions")
print("--------------------------------------")

local plainList = {5, 3, 8, 1, 9, 3, 5}
print("Original plain list:", table.concat(plainList, ", "))

local unique = randomizer.removeDuplicates(plainList)
print("Remove duplicates:", table.concat(unique, ", "))

local sorted = randomizer.sort(unique)
print("Sorted:", table.concat(sorted, ", "))

local shuffledList = randomizer.shuffle(sorted)
print("Shuffled:", table.concat(shuffledList, ", "))

local randomSelection = randomizer.selectRandom(shuffledList, 3)
print("Select 3 random:", table.concat(randomSelection, ", "))
print()

print("=== Examples Complete ===")



