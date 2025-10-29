-- Luacheck configuration
std = "lua53"

-- Ignore some common warnings
ignore = {
    "212", -- Unused argument
    "213", -- Unused loop variable
}

-- Global variables that are okay to use
globals = {
    "describe",
    "it",
    "setup",
    "teardown",
    "before_each",
    "after_each",
    "assert",
}

-- Files to exclude
exclude_files = {
    ".luarocks",
    "*.rockspec",
}

-- Per-file overrides
files["spec/"] = {
    std = "+busted"
}



