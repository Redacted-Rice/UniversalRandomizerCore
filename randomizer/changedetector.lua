--- Change detection module for tracking object modifications
-- Supports multiple entries to track with their own associated parameters
-- Snapshots and comparisons must be called manually when desired
-- @module randomizer.changedetector

local changedetector = {}

-- Monitored data
local monitoredEntries = {}
-- Is change detection active
local isChangeDetectionActive = false

--- Configure global change detection settings
-- @param active boolean whether change detection is active. Defaults to false
function changedetector.configure(active)
	isChangeDetectionActive = active or false
end

--- Add a monitoring entry of objects
-- @param entryName string name for this entry for tracking/logging
-- @param objects array of objects to monitor
-- @param fieldsOrFn table of field names or function that takes first object and returns field names
-- @param identifierFn (optional) function that takes an object and returns a string identifier for
-- logging. If not provided it will use to string
function changedetector.monitor(entryName, objects, fieldsOrFn, identifierFn)
	if not entryName or not objects or not fieldsOrFn then
		print("Warning: Change detector: monitor requires entryName, objects, and fieldsOrFn")
		return
	end

	if #objects == 0 then
		print("Warning: Change detector: no objects provided for '" .. entryName .. "'")
		return
	end

	-- Get the fields we will be monitoring
	local fields
	if type(fieldsOrFn) == "function" then
		fields = fieldsOrFn(objects[1])
		if not fields or type(fields) ~= "table" then
			print("Warning: Change detector: fieldsOrFn function must return a table of field names")
			return
		end
	else
		fields = fieldsOrFn
	end

    -- store data for the entry
	local entry = {
		objects = objects,
		identifierFn = identifierFn or tostring,
		fields = fields,
		snapshot = nil, -- Will be set when takeSnapshots is called
	}
	monitoredEntries[entryName] = entry
end

--- Stop monitoring a specific entry
-- @param entryName string name of the entry to stop monitoring
function changedetector.stopMonitoring(entryName)
	monitoredEntries[entryName] = nil
end

--- Stop monitoring all entries
function changedetector.stopMonitoringAll()
	monitoredEntries = {}
end

--- Capture state of a single object
-- @param obj the object to capture
-- @param fields table of field names to capture
-- @return table capturing current values
local function captureState(obj, fields)
	local state = {}
    -- TODO: Maybe instead have support for field names or getter functions. This could probably
    -- be more flexible and dynamic then

	-- Read each field value
	for _, fieldName in ipairs(fields) do
		local value = nil

		-- Try getter method first
		local getterName = "get" .. fieldName:sub(1,1):upper() .. fieldName:sub(2)
		local getterSuccess, getterValue = pcall(function()
			return obj[getterName](obj)
		end)

		if getterSuccess and getterValue ~= nil then
			value = getterValue
		else
			-- Fall back to direct field access which only works for public fields
			local directSuccess, directValue = pcall(function()
				return obj[fieldName]
			end)
			if directSuccess and directValue ~= nil then
				value = directValue
			end
		end

		if value ~= nil then
			state[fieldName] = value
		end
	end

	return state
end

--- Take a new snapshot of all configured monitoring entries
function changedetector.takeSnapshots()
	if not changedetector.isActive() then
		return
	end

	for entryName, entry in pairs(monitoredEntries) do
		local newSnapshot = {}
        for _, obj in ipairs(entry.objects) do
			local snapshot = {}
			snapshot.object = obj

            local success, result = pcall(entry.identifierFn, obj)
            if success then
                snapshot.identifier = result
            else
                print("ERROR: Failed to call identifierFn for entry: " .. entryName .. " - " .. tostring(result))
                snapshot.identifier = tostring(obj)
            end

			snapshot.state = captureState(obj, entry.fields)
			table.insert(newSnapshot, snapshot)
		end

		-- save the new snapshot
		entry.snapshot = newSnapshot
	end
end

--- Deep compare two values
-- @param v1 first value
-- @param v2 second value
-- @return true if values are equal
local function deepCompare(v1, v2)
	-- Simple comparison for non-tables
	local t1, t2 = type(v1), type(v2)

	if t1 ~= t2 then
		return false
	end

	if t1 ~= "table" and t1 ~= "userdata" then
		return v1 == v2
	end

	-- For userdata and tables, use tostring comparison
    -- TODO: for a true deep compare it should probably recurse
	return tostring(v1) == tostring(v2)
end

--- Detect changes since last snapshot for all monitoring entries
-- @return table mapping entry names to object changes
function changedetector.detectChanges()
	local allChanges = {}

	for entryName, entry in pairs(monitoredEntries) do
		if not entry.snapshot then
            -- Lua doesn't have continue... use goto instead
			goto continue
		end

		local entryChanges = {}
		for _, snapshot in ipairs(entry.snapshot) do
			local currentState = captureState(snapshot.object, entry.fields)
			local changes = {}

			-- Check each field in the snapshot
			for fieldName, oldValue in pairs(snapshot.state) do
				local newValue = currentState[fieldName]

				if not deepCompare(oldValue, newValue) then
					changes[fieldName] = {
						old = tostring(oldValue),
						new = tostring(newValue),
					}
				end
			end

			-- Add to results if there are changes
			if next(changes) then
				entryChanges[snapshot.identifier] = changes
			end
		end

		-- Only add entry if it has changes
		if next(entryChanges) then
			allChanges[entryName] = entryChanges
		end

		::continue::
	end

	return allChanges
end

--- Check if there are any changes in the changes table
-- @param changes table of changes from detectChanges()
-- @return boolean true if there are changes
function changedetector.hasChanges(changes)
	return next(changes) ~= nil
end

--- Check if change detection is active
-- @return boolean
function changedetector.isActive()
	return isChangeDetectionActive
end

--- Get list of monitored entry names
-- @return table of entry names
function changedetector.getMonitoredEntryNames()
	local names = {}
	for name, _ in pairs(monitoredEntries) do
		table.insert(names, name)
	end
	return names
end

return changedetector
