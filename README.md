# Universal Randomizer

Lua based randomization functions to support randomizing arbitrary lists of objects and their parameters

## Features

- **Chainable API**: Fluent interface for composing operations
- **List/Group Management**: Filter, sort, shuffle, remove duplicates, and select items
- **Pools and Grouped Pools**: Define pools to pull values from including having multiple pools to select from based on conditions
- **Hybrid API**: Works with both wrapper objects and plain tables
- **Type-Safe**: Built-in validation and helpful error messages
- **Reproducible**: Uses randomization built in to lua which supports seeds

## Requirements

- Lua 5.3 or higher

## Installation

Simply copy the `randomizer/` directory to your project and require it:

```lua
local randomizer = require("randomizer")
```
## Quick Start

### Simple List Randomization

```lua
local randomizer = require("randomizer")

-- Create a pool of replacement values
local pool = randomizer.list({"Apple", "Banana", "Cherry"})

-- Randomize a target list
local items = {"Item1", "Item2", "Item3"}
pool:randomize(items)

print(table.concat(items, ", "))  -- e.g., "Banana, Apple, Cherry"
```

### Grouped Randomization

```lua
-- Define weapons with types
local weapons = {
    {name = "sword_001", type = "melee"},
    {name = "bow_001", type = "ranged"},
    {name = "axe_001", type = "melee"}
}

-- Create separate pools for each weapon type
local weaponPools = randomizer.group({
    melee = {"Sword", "Axe", "Mace", "Spear"},
    ranged = {"Bow", "Crossbow", "Rifle", "Pistol"}
})

-- Extract weapon names
local names = {}
for i, weapon in ipairs(weapons) do
    names[i] = weapon.name
end

-- Randomize using weapon type as selector
weaponPools:randomize(names, function(name, index)
    return weapons[index].type
end)

-- Each weapon is now replaced with a random weapon of the same type
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

## Examples

See `example.lua` for comprehensive examples demonstrating many features.

Run the examples:

```bash
lua example.lua
```
## Testing

The library uses [Busted](https://olivinelabs.com/busted/) for testing.

### Running Tests

Install Busted:

```bash
luarocks install busted
```

Run all tests:

```bash
busted
```

Run specific test files:

```bash
# Run all unit tests
busted spec/list_spec.lua spec/group_spec.lua spec/utils_spec.lua spec/init_spec.lua

# Run functional tests
busted spec/functional_spec.lua

# Run specific module tests
busted spec/list_spec.lua
busted spec/group_spec.lua
```

### Test Suite

The test suite includes tests organized by module:

**Unit Tests**:
- `spec/list_spec.lua` - List class tests
- `spec/group_spec.lua` - Group class tests
- `spec/utils_spec.lua` - Utility functions tests
- `spec/init_spec.lua` - Standalone functions tests

These unit tests cover:
- Individual method testing
- Edge cases and error handling
- API correctness verification

**Functional Tests**:
- `spec/functional_spec.lua` - End-to-end workflows

These unit tests cover:
- Real-world use case scenarios
- Game modding (weapon randomization, enemy loot)
- Procedural generation (dungeon rooms)
- Complex multi-stage processing
- Integration testing

### Code Coverage

Install LuaCov:

```bash
luarocks install luacov
```

Run tests with coverage:

```bash
busted --coverage
```

Generate coverage report:

```bash
luacov
```

View the report in `luacov.report.out`. The library currently has > 99% coverage

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

## Design Philosophy

- **Flexibility**: Works with both objects and plain tables
- **Composability**: Chain operations for complex transformations
- **Clarity**: Clear error messages and type validation

## License

MIT License - Feel free to use in your projects!

## Version

0.7.0



