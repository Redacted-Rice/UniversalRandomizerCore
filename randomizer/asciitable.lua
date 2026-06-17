--- ASCII table formatting utilities
-- Luaj seems to ignore string.format width specifiers, so padding is done explicitly.
-- @module randomizer.asciitable

local asciitable = {}

--- Format one table cell with manual padding
-- @param value any cell value
-- @param width number target column width
-- @param align string "left" or "right"
-- @return string padded cell text without surrounding pipes
function asciitable._formatCell(value, width, align)
	local text = tostring(value or "")
	if width > 0 and #text > width then
		text = text:sub(1, width)
	end

	local padding = width - #text
	if padding <= 0 then
		return text
	end

	if align == "right" then
		return string.rep(" ", padding) .. text
	end

	return text .. string.rep(" ", padding)
end

--- Calculate total rendered width of a table row including pipe separators
-- @param widths table column widths
-- @return number total row width
function asciitable._rowWidth(widths)
	local width = 1
	for _, columnWidth in ipairs(widths) do
		width = width + columnWidth + 1
	end
	return width
end

--- Build a separator line for the ASCII table
-- @param widths table column widths
-- @return string separator row
function asciitable._separatorLine(widths)
	local parts = { "|" }
	for _, columnWidth in ipairs(widths) do
		table.insert(parts, string.rep("-", columnWidth))
		table.insert(parts, "|")
	end
	return table.concat(parts)
end

--- Build the centered title row for a table
-- @param title string title text without surrounding pipes
-- @param totalWidth number full rendered table width
-- @return string title row
function asciitable._titleRow(title, totalWidth)
	local innerWidth = math.max(totalWidth - 2, #title)
	local spacing = innerWidth - #title
	local leftPadding = math.floor(spacing / 2)
	local rightPadding = spacing - leftPadding
	return "|"
		.. string.rep(" ", leftPadding)
		.. title
		.. string.rep(" ", rightPadding)
		.. "|"
end

--- Expand the table width when content requires a wider layout
-- Prevents Luaj string.rep from receiving a negative repeat count
-- @param widths table column widths, modified in place
-- @param minWidth number minimum required table width
function asciitable._ensureMinWidth(widths, minWidth)
	local currentWidth = asciitable._rowWidth(widths)
	if currentWidth >= minWidth then
		return
	end

	widths[#widths] = widths[#widths] + (minWidth - currentWidth)
end

--- Format one data or header row for the ASCII table
-- @param columns table column definitions with align
-- @param widths table column widths
-- @param values table cell values in column order
-- @return string formatted row
function asciitable._formatRow(columns, widths, values)
	local parts = { "|" }
	for index, columnWidth in ipairs(widths) do
		table.insert(parts, asciitable._formatCell(values[index], columnWidth, columns[index].align))
		table.insert(parts, "|")
	end
	return table.concat(parts)
end

--- Compute column widths from headers and row cell values
-- @param columns table array of { header, align }
-- @param rows table array of row value arrays aligned to columns
-- @return table column widths
function asciitable.computeColumnWidths(columns, rows)
	local widths = {}

	for index, column in ipairs(columns) do
		widths[index] = #column.header
	end

	for _, rowValues in ipairs(rows) do
		for index, value in ipairs(rowValues) do
			local length = #tostring(value)
			if length > widths[index] then
				widths[index] = length
			end
		end
	end

	return widths
end

--- Render an ASCII table
-- @param config table:
--   title (optional) centered title row text
--   columns table array of { header, align }
--   rows table array of row value arrays
--   headerEvery (optional) repeat header every N data rows
--   trailingHeader (optional) boolean repeat header after final row
-- @return string formatted table
function asciitable.render(config)
	local columns = config.columns
	local rows = config.rows or {}
	local headers = {}

	for _, column in ipairs(columns) do
		table.insert(headers, column.header)
	end

	local widths = asciitable.computeColumnWidths(columns, rows)
	if config.title then
		asciitable._ensureMinWidth(widths, #config.title + 2)
	end

	local outputLines = {}
	local tableWidth = asciitable._rowWidth(widths)

	local function appendHeaderBlock()
		table.insert(outputLines, asciitable._separatorLine(widths))
		table.insert(outputLines, asciitable._formatRow(columns, widths, headers))
		table.insert(outputLines, asciitable._separatorLine(widths))
	end

	if config.title then
		table.insert(outputLines, asciitable._titleRow(config.title, tableWidth))
	end

	appendHeaderBlock()

	for rowIndex, rowValues in ipairs(rows) do
		if config.headerEvery and rowIndex > 1 and (rowIndex - 1) % config.headerEvery == 0 then
			appendHeaderBlock()
		end

		table.insert(outputLines, asciitable._formatRow(columns, widths, rowValues))
	end

	if config.trailingHeader then
		appendHeaderBlock()
	end

	return table.concat(outputLines, "\n")
end

return asciitable
