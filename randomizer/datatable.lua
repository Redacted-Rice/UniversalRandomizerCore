--- Format lists of objects as ASCII tables using shared layout configuration
-- @module randomizer.datatable

local asciitable = require("randomizer.asciitable")
local tablelayout = require("randomizer.tablelayout")

local datatable = {}

--- Format objects as an ASCII table
-- @param objects table array of objects to display
-- @param config table layout config:
--   title (optional) table title shown in formatted output
--   headerEvery (optional) repeat column headers every N data rows
--   trailingHeader (optional) repeat column headers after the final data row
--   primaryKey table { header, align, numeric, field or getter } sort/display key
--   description (optional) table { header, align, field or getter } display-only column
--   fields array of { field or getter, header, align } value columns
-- @param options table|nil optional formatting options:
--   title string full title row text override
--   leadingNewline boolean prepend a newline before the formatted output
-- @return string formatted table, or empty string when there are no objects
function datatable.format(objects, config, options)
	if not objects or #objects == 0 then
		return ""
	end

	local entry, configError = tablelayout._normalizeLayoutConfig(config)
	if not entry then
		print("Warning: Data table: invalid layout config: " .. (configError or "unknown error"))
		return ""
	end

	options = options or {}
	local columns = tablelayout._buildDisplayColumns(entry)
	local sortedRows = tablelayout._sortedRows(objects, entry)
	local rows = {}

	for _, rowData in ipairs(sortedRows) do
		table.insert(rows, tablelayout._buildDisplayRowValues(rowData, entry))
	end

	local title = options.title or entry.title or "Data"
	local tableOutput = asciitable.render({
		title = title,
		columns = columns,
		rows = rows,
		headerEvery = entry.headerEvery,
		trailingHeader = entry.trailingHeader,
	})

	return asciitable.applyOutputOptions(tableOutput, options)
end

return datatable
