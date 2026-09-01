--[[
Layouter
UI Grid Layout Library for LÖVE 2D Game Engine
© Daniel Duris, dusoft@staznosti.sk, 2023+
License: GNU LGPL 3.0
]]--

local layouter = {
    _NAME = "Layouter",
    _DESCRIPTION = 'UI Grid Layout Library for LÖVE 2D Game Engine',
    _URL = 'https://github.com/nekromoff/layouter',
    _VERSION = 2,
    _LICENSE = "LGPL 3.0",
    _LOVE = 11.4,
    ---------------------------
    ROWS = 16,
    COLUMNS = 24,
    elements = {},
    _layout = {},
    _helpers = {},
}

-- @param table options
layouter.initialize = function(options)
    options = options or {}
    layouter.font = options.font or love.graphics.newFont(15)
    layouter.background = options.background or {255, 255, 255}
    layouter.color = options.color or {0, 0, 0}
    layouter.debug = options.debug or false
    local width, height = love.window.getMode()
    layouter._calculateGrid(width, height)
    layouter.reset()
end

-- recalculate grid, to be used in love.resize() function
-- @param number new window width
-- @param number new window height
layouter.resize = function(width, height)
    if width == nil or height == nil then
        width, height = love.window.getMode()
    end
    layouter._calculateGrid(width, height)
    -- reflow already added elements using the remembered layout options
    if layouter._previous then
        layouter.prepare()
    end
end

-- calculate column/row sizes and precalculate pixel shortcuts
layouter._calculateGrid = function(width, height)
    layouter.COLUMN_WIDTH = layouter._helpers.math_round(width / layouter.COLUMNS)
    layouter.ROW_HEIGHT = layouter._helpers.math_round(height / layouter.ROWS)
    -- precalculate pixels for each column/row to allow for using shortcuts, e.g. layouter.COLUMN5 or layouter.ROW2
    -- (yeah, similar to Bootstrap CSS grid)
    for column = 1, layouter.COLUMNS do
        layouter['COLUMN'..column] = layouter.COLUMN_WIDTH * column
    end
    for row = 1, layouter.ROWS do
        layouter['ROW'..row] = layouter.ROW_HEIGHT * row
    end
end

layouter.reset = function()
    layouter.elements = {}
    layouter._layout = {}
    layouter._previous = nil
end

-- add element to layout
-- @param nil/string/table element options
-- @return string key assigned to the element
layouter.add = function (element)
    element = layouter._createElement(element)
    layouter.elements[#layouter.elements + 1] = element
    return element.key
end

-- add element into a group, i.e. into an existing (or new) row/column
-- @param string group name
-- @param nil/string/table element options
-- @return string key assigned to the element
layouter.addTo = function (group, element)
    if type(element) ~= 'table' then
        element = {content = element}
    end
    element.group = group
    return layouter.add(element)
end

-- replace existing element in layout by a new one
-- @param string existing element_key
-- @param nil/string/table element options
layouter.replace = function(element_key, element)
    local replacement = layouter._createElement(element, element_key)
    for temp_key = 1, #layouter.elements do
        if layouter.elements[temp_key].key == element_key then
            layouter.elements[temp_key] = replacement
        end
    end
    -- call prepare automatically to update screen on next draw (prepare remembers previous state)
    layouter.prepare()
end

-- remove existing element from layout
-- @param string existing element_key
layouter.remove = function(element_key)
    -- iterate backwards, removal shifts all following indexes
    for key = #layouter.elements, 1, -1 do
        if layouter.elements[key].key == element_key then
            table.remove(layouter.elements, key)
        end
    end
    -- keep the drawn layout in sync, same as replace() does
    layouter.prepare()
end

-- setup an element to be added to layout
-- @param nil/string/table element options
-- @param nil/string key to force (used by replace)
layouter._createElement = function(element, forced_key)
    -- change empty content for adding text to proper table
    if element == nil then
        element = {}
        element.content = ''
    elseif type(element) == 'string' then -- change simplified format for adding text to proper table
        local temp_content = element
        element = {}
        element.content = temp_content
    end
    element.content = element.content or ''
    element.type = element.type or 'text'
    element.callback = element.callback or false
    element.font = element.font or layouter.font or love.graphics.getFont()
    element.color = element.color or layouter.color
    element.background = element.background or layouter.background
    element.align = element.align or 'center'
    -- elements sharing a group are laid out in one row/column
    element.group = element.group or false
    element.key = forced_key or element.key
    if element.key == nil then
        element.key = layouter._helpers.unique_key(element)
    end
    -- grid shortcuts: column/row are offsets in cells, identical to the layouter.COLUMNn/ROWn constants
    -- (column = 6 is the same X as layouter.COLUMN6, column = 0 is the left edge); spans are counted in cells
    if element.column then
        element.x = layouter.COLUMN_WIDTH * element.column
        element.width = element.width or layouter.COLUMN_WIDTH * (element.column_span or 1)
    end
    if element.row then
        element.y = layouter.ROW_HEIGHT * element.row
        element.height = element.height or layouter.ROW_HEIGHT * (element.row_span or 1)
    end
    element.x = element.x or false
    element.y = element.y or false
    -- if exact location is provided, precalculate missing dimensions
    if (element.x or element.y) and (element.width == nil or element.height == nil) then
        local width, height
        if element.type == 'image' then
            width, height = element.content:getDimensions()
        else
            local temp_text = love.graphics.newText(element.font, element.content)
            width, height = temp_text:getDimensions()
        end
        element.width = element.width or width
        element.height = element.height or height
    end
    return element
end

-- split automatically positioned elements into tracks (rows in a horizontal, columns in a vertical layout)
-- elements sharing a group stay in one track, a track wraps into more tracks when its elements
-- would get smaller than the minimum
-- @param table layout options
layouter._computeTracks = function(layout)
    -- collect the groups in the order they first appear, ungrouped elements share one implicit group
    local groups = {}
    local group_numbers = {}
    for _, element in ipairs(layouter.elements) do
        if element.x == false and element.y == false then
            local name = element.group or ''
            if group_numbers[name] == nil then
                groups[#groups + 1] = {name = name, elements = {}}
                group_numbers[name] = #groups
            end
            local elements = groups[group_numbers[name]].elements
            elements[#elements + 1] = element
        end
    end
    local tracks = {}
    for _, group in ipairs(groups) do
        local count = #group.elements
        local line_height = 0
        for _, element in ipairs(group.elements) do
            line_height = math.max(line_height, element.font:getHeight())
        end
        local per_track = count
        if layout.overflow == 'wrap' then
            local available, minimum
            if layout.direction == 'horizontal' then
                available = layout.spacing.width
                minimum = layout.min_width
            else -- vertical elements are never squeezed below one line of text
                available = layout.spacing.height
                minimum = layout.min_height or line_height + layout.padding * 2
            end
            if minimum and available / count - layout.padding * 2 < minimum then
                per_track = math.max(math.floor(available / (minimum + layout.padding * 2)), 1)
                -- balance the tracks, so the last one is not left with a single element
                per_track = math.ceil(count / math.ceil(count / per_track))
            end
        end
        for first = 1, count, per_track do
            -- slots, not the number of elements: a partial last track keeps the same element size
            local track = {group = group.name, elements = {}, slots = per_track, line_height = line_height}
            for number = first, math.min(first + per_track - 1, count) do
                track.elements[#track.elements + 1] = group.elements[number]
            end
            tracks[#tracks + 1] = track
        end
    end
    return tracks
end

-- prepares a layout, does all computations for elements, assigns positions, does autosizing etc.
-- @param table layout options
layouter.prepare = function(layout)
    layouter._layout = {}
    layout = layout or {}
    -- fill in whatever the caller did not specify from the previous state, if it was not reset
    if layouter._previous then
        layout.x = layout.x or layouter._previous.x
        layout.y = layout.y or layouter._previous.y
        layout.direction = layout.direction or layouter._previous.direction
        layout.spacing = layout.spacing or layouter._previous.spacing
        layout.padding = layout.padding or layouter._previous.padding
        layout.overflow = layout.overflow or layouter._previous.overflow
        layout.min_width = layout.min_width or layouter._previous.min_width
        layout.min_height = layout.min_height or layouter._previous.min_height
    end
    layout.x = layout.x or 0
    layout.y = layout.y or 0
    layout.width, layout.height = love.window.getMode()
    layout.direction = layout.direction or 'vertical'
    layout.padding = layout.padding or 10
    layout.overflow = layout.overflow or 'none'
    if layout.spacing == 'auto' then
        -- center the elements: leave the same gap on the opposite side as before x/y
        layout.spacing = {width = layout.width - layout.x * 2, height = layout.height - layout.y * 2}
    elseif layout.spacing == nil then
        -- default: everything from x/y to the opposite window edge
        layout.spacing = {width = layout.width - layout.x, height = layout.height - layout.y}
    end
    -- remember current state
    layouter._previous = {x = layout.x, y = layout.y, direction = layout.direction, spacing = layout.spacing,
        padding = layout.padding, overflow = layout.overflow, min_width = layout.min_width,
        min_height = layout.min_height}
    -- only automatically positioned elements share the available space
    local tracks = layouter._computeTracks(layout)
    local track_width
    if layout.direction ~= 'horizontal' and #tracks > 0 then
        -- columns divide the available width between themselves
        track_width = layout.spacing.width / #tracks - layout.padding * 2
    end
    local positions = {}
    local track_x = layout.x
    local track_y = layout.y
    local extent = 0
    for track_number, track in ipairs(tracks) do
        local last_x = track_x
        local last_y = track_y
        for _, element in ipairs(track.elements) do
            local position = {track = track_number, group = track.group}
            if layout.direction == 'horizontal' then
                position.width = layout.spacing.width / track.slots - layout.padding * 2
                position.height = track.line_height + layout.padding * 2
                position.x = layout.padding + last_x
                position.y = track_y
                last_x = position.x + position.width + layout.padding
                extent = math.max(extent, position.y + position.height)
            else
                position.width = track_width
                position.height = layout.spacing.height / track.slots - layout.padding * 2
                position.x = track_x + layout.padding
                position.y = layout.padding + last_y
                last_y = position.y + position.height + layout.padding
                extent = math.max(extent, position.x + position.width)
            end
            positions[element] = position
        end
        -- next track starts after this one, on the other axis
        if layout.direction == 'horizontal' then
            track_y = track_y + track.line_height + layout.padding * 3
        else
            track_x = track_x + track_width + layout.padding * 2
        end
    end
    -- elements do not fit into the available space, nothing is clipped, they just run over
    if layout.direction == 'horizontal' then
        layouter._overflowing = extent > layout.y + layout.spacing.height + 0.001
    else
        layouter._overflowing = extent > layout.x + layout.spacing.width + 0.001
    end
    -- keep the original order, so elements are drawn in the order they were added
    for _, element in ipairs(layouter.elements) do
        local prepared_element = layouter._helpers.table_copy(element)
        local position = positions[element]
        -- do automatic layout, if x and y not set directly
        if position then
            prepared_element.x = position.x
            prepared_element.y = position.y
            prepared_element.width = position.width
            prepared_element.height = position.height
            prepared_element.track = position.track
        else
            -- partially positioned element: fill the missing coordinate from the layout
            prepared_element.x = prepared_element.x or layout.x
            prepared_element.y = prepared_element.y or layout.y
        end
        layouter._layout[#layouter._layout + 1] = prepared_element
    end
end

-- draw a layout, to be used in love.draw() function
layouter.draw = function()
    local x, y = love.mouse.getPosition()
    love.graphics.clear(love.math.colorFromBytes(layouter.background))
    if layouter.debug then
        love.graphics.setColor(love.math.colorFromBytes(176, 176, 176))
        love.graphics.setFont(layouter.font)
        local grid_width = layouter.COLUMNS * layouter.COLUMN_WIDTH
        local grid_height = layouter.ROWS * layouter.ROW_HEIGHT
        for column = 0, layouter.COLUMNS do
            love.graphics.line(column * layouter.COLUMN_WIDTH, 0, column * layouter.COLUMN_WIDTH, grid_height)
        end
        for row = 0, layouter.ROWS do
            love.graphics.line(0, row * layouter.ROW_HEIGHT, grid_width, row * layouter.ROW_HEIGHT)
        end
        for column = 0, layouter.COLUMNS do
            for row = 0, layouter.ROWS do
                love.graphics.print(column..','..row, column * layouter.COLUMN_WIDTH, row * layouter.ROW_HEIGHT)
            end
        end
    end
    love.graphics.setColor(love.math.colorFromBytes(layouter.color))
    for _, element in ipairs(layouter._layout) do
        if element.type == 'button' then
            if layouter._helpers.is_inside(element, x, y) then
                love.graphics.setColor(love.math.colorFromBytes(element.color))
                love.graphics.rectangle('fill', element.x, element.y, element.width, element.height)
                love.graphics.setColor(love.math.colorFromBytes(element.background))
            else
                love.graphics.setColor(love.math.colorFromBytes(element.color))
                love.graphics.rectangle('line', element.x, element.y, element.width, element.height)
            end
            love.graphics.printf(element.content, element.font, element.x, layouter._helpers.text_y(element), element.width, element.align)
        elseif element.type == 'text' then
            love.graphics.setColor(love.math.colorFromBytes(element.color))
            love.graphics.printf(element.content, element.font, element.x, layouter._helpers.text_y(element), element.width, element.align)
        else -- image
            -- images are drawn untinted (the background color used to tint them)
            love.graphics.setColor(1, 1, 1, 1)
            local image_width, image_height = element.content:getDimensions()
            local scale_x = (element.width or image_width) / image_width
            local scale_y = (element.height or image_height) / image_height
            love.graphics.draw(element.content, element.x, element.y, 0, scale_x, scale_y)
        end
    end
end

-- process mouse callbacks, to be used in love.mousepressed() function
-- currently supports only default (usually left) button
layouter.processMouse = function(x, y, mouse_button, is_touch)
    if mouse_button ~= 1 then
        return
    end
    for _, element in ipairs(layouter._layout) do
        if element.callback ~= false and layouter._helpers.is_inside(element, x, y) then
            element.callback()
        end
    end
end

-- vertically center the (possibly wrapped) content within the element box
layouter._helpers.text_y = function(element)
    local line_height = element.font:getHeight()
    local content_height = line_height
    if element.width and element.width > 0 then
        local _, lines = element.font:getWrap(element.content, element.width)
        content_height = math.max(#lines, 1) * line_height
    end
    return layouter._helpers.math_round(element.y + (element.height - content_height) / 2)
end

layouter._helpers.is_inside = function(element, x, y)
    if not element.width or not element.height then
        return false
    end
    return x >= element.x and x <= element.x + element.width and y >= element.y and y <= element.y + element.height
end

-- generate identifier / key using only a-z0-9_, unique within the current layout
layouter._helpers.unique_key = function(element)
    local key
    if type(element.content) == 'string' and element.content ~= '' then
        key = string.gsub(element.content:lower(), '%W', '')
    end
    if key == nil or key == '' then
        key = element.type
    end
    local candidate = key
    local suffix = 1
    while layouter._helpers.key_exists(candidate) do
        suffix = suffix + 1
        candidate = key..suffix
    end
    return candidate
end

layouter._helpers.key_exists = function(key)
    for _, element in ipairs(layouter.elements) do
        if element.key == key then
            return true
        end
    end
    return false
end

layouter._helpers.math_round = function(number, decimal_places)
    local multiplicator = 10 ^ (decimal_places or 0)
    return math.floor(number * multiplicator + 0.5) / multiplicator
end

layouter._helpers.table_copy = function (orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[layouter._helpers.table_copy(orig_key)] = layouter._helpers.table_copy(orig_value)
        end
        setmetatable(copy, layouter._helpers.table_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return layouter
