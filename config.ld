-- ldoc configuration file
project = 'Randomizer Core'
title = 'Universal Randomizer Core'
description = 'Lua based randomization functions to support randomizing arbitrary lists of objects and their parameters'
format = 'markdown'
dir = 'docs'

style = "!"

-- source files
file = {
    'randomizer/init.lua',
    'randomizer/list.lua',
    'randomizer/group.lua',
    'randomizer/utils.lua',
}

-- readme file
readme = 'README.md'

-- dont show local functions by default
all = false

-- sort modules alphabetically
sort_modules = true

-- dont merge examples
merge = false

-- output format
format = 'discount'

