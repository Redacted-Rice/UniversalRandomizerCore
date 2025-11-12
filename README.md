# Universal Randomizer

Lua based randomization functions to support randomizing arbitrary lists of objects and their parameters

## Features

- Chainable API: Fluent interface for composing operations
- List/Group Management: Filter, sort, shuffle, remove duplicates, and select items
- Pools and Grouped Pools: Define pools to pull values from including having multiple pools to select from based on conditions
- Hybrid API: Works with both wrapper objects and plain tables
- Type-Safe: Built-in validation and helpful error messages
- Reproducible: Uses randomization built in to lua which supports seeds

Note: Performances, both speed and for large data sets, was not considered

## Requirements

Lua 5.3 or higher

## License

MIT - Feel free to use in your projects!

## Version

0.9.0

## Design Philosophy

- Flexibility: Works with both objects and plain tables
- Composability: Chain operations for complex transformations
- Clarity: Clear error messages and type validation
- Non-performant: Did not worry about performance on large data sets

## Use Cases

### Game Modding
- Randomize weapon/item drops based on enemy types
- Shuffle level layouts or enemy spawns
- Create procedural loot tables with rarity tiers

### Procedural Generation
- Generate varied content from predefined pools
- Create rule-based randomization systems
- Build weighted random selection systems

### Data Shuffling
- Randomize test data while maintaining relationships
- Create reproducible random datasets
- Transform lists with complex rules

## Installation

Simply copy the `randomizer/` directory to your project and require it:

```lua
local randomizer = require("randomizer")
```

## Quick Start

### Simple List Randomization without In-Place Field Updates

```lua
local randomizer = require("randomizer")

-- Create a pool of replacement values
local pool = randomizer.list({"Apple", "Banana", "Cherry"})

-- Randomize a target list
local items = {"Item1", "Item2", "Item3"}
pool:randomize(items)

print(table.concat(items, ", "))  -- e.g., "Banana, Apple, Cherry"
```

### Grouped Randomization with In-Place Field Updates

```lua
-- Define weapons with types
local weapons = {
    {name = "sword_001", type = "melee", damage = 10},
    {name = "bow_001", type = "ranged", damage = 8},
    {name = "axe_001", type = "melee", damage = 12}
}

-- Create separate pools for each weapon type
local weaponPools = randomizer.group({
    melee = {"Sword", "Axe", "Mace", "Spear"},
    ranged = {"Bow", "Crossbow", "Rifle", "Pistol"}
})

-- Randomize the 'name' field directly on weapon objects
weaponPools:randomize(weapons, function(weapon)
    return weapon.type
end, "name")  -- "name" is the field to update

-- Each weapon.name is now updated in place based on weapon.type
-- Other fields (damage, type) remain unchanged

-- Or use a custom setter function for complex updates:
weaponPools:randomize(weapons, function(weapon)
    return weapon.type
end, function(weapon, newName, index)
    weapon.name = newName
    weapon.renamed = true
end)
```

### Chainable Operations

```lua
local numbers = randomizer.list({5, 2, 8, 2, 1, 9, 5, 3})

local result = numbers
    :removeDuplicates()  -- {5, 2, 8, 1, 9, 3}
    :sort()              -- {1, 2, 3, 5, 8, 9}
    :filter(function(x) return x > 3 end)  -- {5, 8, 9}

print(table.concat(result:toTable(), ", "))  -- "5, 8, 9"
```

## More Examples

See `example.lua` for examples showing many features and typical use cases for how this library is expected to be used

Run the examples:

```bash
lua example.lua
```

## Core Concepts

This is a high level explanation of the main ideas in this library. For full API details, check out the comments in the code.

### Lists

A **List** is a wrapper around array-like Lua tables. They are primarily used to allow further refinement or downselecting of the list and are used to hold the items being randomized as well as basic pools to select values from for randomization.

**Key behaviors:**
- Lists are read-only - operations like `filter()` or `shuffle()` create new Lists, they don't change the original
- You can chain operations together (e.g., `list:filter(...):sort(...):shuffle(...)`)
- Lists can be used as **pools** for randomization - when you randomize items, values are picked from teh pool

Example: If you have a List of weapon names `{"Sword", "Axe", "Bow"}`, you can use it to randomly assign weapons to characters in your game.

### Groups

A **Group** is a collection of multiple Lists, each associated with a specific key. THis is primarily meant to provide bulk, subset randomization of lists. For example if you want to randomizing something by type, you could loop through each type and downselect a List or instead you can use a group with type as the key to randomize in bult

**When to use Groups:**
- You need different pools based on some condition (e.g., different weapon pools for melee vs ranged)
- You want to randomize items differently depending on their properties
- You have categorized data that should stay separate

Example: a Group might have `melee = {"Sword", "Axe"}` and `ranged = {"Bow", "Crossbow"}`. When randomizing, you pick which pool to use based on the weapon's type.

### Common List/Group Operations

**`select`** - Extract specific values from items. If you have a list of items with a `name` field, `select("name")` gives you a list of just the names.

**`filter`** - Keep only items that match a condition. For example, `filter(function(x) return x.health > 5 end)` keeps only items with health greater than 5.

**`shuffle`** - randomly reorder the items in the list. Like shuffling a deck of cards.

### How Randomization Works

The library can randomize items in two ways:

- In-place modification - The expected typical pattern. You pass a list of objects, and the library directly modifies their fields (like `weapon.name` or `character.weapon`). YOur original objects get updated.

- Creating new lists - operations like `shuffle()`, `filter()`, and `sort()` return new Lists without modifying the original. This lets you safely chain operations together.

**Understanding Randomization Arguments**

**`toRandomize`** - the list of items that are going to be modified in place with the new values

**`pool`** - the list or group of values that can be selected from when randomizing

**`poolOptions`** - defines how the pool behaves

- **`consume`** - whether the pool is consumable or not. defaults to non-consumable. If true, when items are selected, they're removed from the pool. If false, they stay in the pool.
    - **consumable** pools are like a bag where you pull an item from it and don't put it back
    - **non-consumable** pools can be thought of like rolling dice. If you roll a value once, you can still roll it again.

- **`regenerate`** - only applicable for consumable pools. If true, when the pool is empty and you try to draw a new value, it will create a new pool with all the initial values. If false, it will throw an error.
    - **regenerating** pools are like a bag and once you draw all the items out of the bag you then put them all back in and continue drawing. This can be used to ensure a more even distribution of values.
    - **non-regenerating** pools are like if you took everyone's phone, threw it in a bag and then everyone took one out. There should be no extras as you're just reassigning/shuffling items. In this case the expectation is that the pool size is the same as the number of items being randomized.

## LDoc Generated Docs

Uses LDoc to generate documentation from the code

Install LDoc:

```bash
luarocks install ldoc
```
Note: On windows the bat creation doesn't seem to work correctly and needs to be manually created

Generate all lua docs:

```bash
ldoc .
```

The files will be generated in the `docs` folder.

## Testing, Coverage, Static Analysis, and Formatting

Uses the following modules on LuaRocks:
- Busted - for testing
- LuaCov - for generating coverage report
- LuaCheck - for static code analysis

### Running Tests

Install Busted:

```bash
luarocks install busted
```
Note: On windows the bat creation doesn't seem to work correctly and needs to be manually created

Run all tests:

```bash
busted
```

Run just functional or just unit tests:

```bash
busted -r unit       # just unit tests
busted -r functional # just functional tests
```

Run specific test files:

```bash
busted spec/unit/list_spec.lua
busted spec/unit/group_spec.lua
```

### Test Explanations

**Unit Tests**:
`spec/unit/` directory
All unit tests can be run with the following command

```bash
busted -r unit
```

Current unit tests
- `spec/unit/list_spec.lua` - List class tests
- `spec/unit/group_spec.lua` - Group class tests
- `spec/unit/utils_spec.lua` - Utility functions tests
- `spec/unit/init_spec.lua` - Standalone functions tests

These unit tests cover:
- Individual method testing
- Edge cases and error handling
- API correctness verification

**Functional Tests**:
`spec/functional_spec.lua` spec file
All functional tests can be run with the following command

```bash
busted -r functional
```

These functional tests cover:
- real-world use case scenarios
- game modding (weapon randomization, enemy loot)
- procedural generation (dungeon rooms)
- complex multi-stage processing
- integration testing

**Coverage Helper Tests**:
`spec/clear_coverage.lua` is not a test but a helper to automatically clear code coverage
statistics when you run to check coverage

### Code Coverage

Install LuaCov:

```bash
luarocks install luacov
```
Note: On windows the bat creation doesn't seem to work correctly and needs to be manually created

Run tests adn generate coverage report:

```bash
busted --coverage
```

You shouldn't need to run `luacov` manually to generate the coverage report - this should be done automatically as part of running busted with coverage. This also uses the
`spec/clear_coverage.lau` script to clear the coverage data from previous runs each time
it is run.

Report is generated in `luacov.report.out`. The library currently has > 99% coverage

### Static Analysis

Install LuaCheck:

```bash
luarocks install luacheck
```
Note: On windows the bat creation doesn't seem to work correctly and needs to be manually created

Run static checks on all files:

```bash
luacheck .
```

### Auto-Formatting

The lua files was formatted with the default formatting rules using the StyLua Visual Studio plugin
