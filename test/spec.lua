-- headless unit tests for layouter, run with: lua test/spec.lua
-- no LÖVE, no GPU needed: the few love.* calls layouter makes are stubbed below

local WINDOW_WIDTH, WINDOW_HEIGHT = 800, 600

local function newFont(size)
    local font = {size = size or 15}
    function font:getHeight() return self.size end
    function font:getWrap(text, limit)
        -- crude wrap: ~10px per character, enough to exercise the centering math
        local characters = #tostring(text)
        local per_line = math.max(math.floor((limit or WINDOW_WIDTH) / 10), 1)
        local lines = {}
        for _ = 1, math.max(math.ceil(characters / per_line), 1) do
            lines[#lines + 1] = ''
        end
        return limit, lines
    end
    return font
end

love = {
    graphics = {
        newFont = newFont,
        getFont = function() return newFont(15) end,
        newText = function(font, content)
            return {getDimensions = function() return #tostring(content) * 10, font:getHeight() end}
        end,
        clear = function() end,
        setColor = function() end,
        setFont = function() end,
        line = function() end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        draw = function() end,
    },
    window = {getMode = function() return WINDOW_WIDTH, WINDOW_HEIGHT end},
    math = {colorFromBytes = function(r, g, b, a)
        if type(r) == 'table' then r, g, b, a = r[1], r[2], r[3], r[4] end
        return r / 255, g / 255, b / 255, a and a / 255 or nil
    end},
    mouse = {getPosition = function() return 0, 0 end},
}

local test_dir = arg[0]:match('(.*[/\\])') or './'
local layouter = dofile(test_dir .. '../layouter.lua')

local failures, total = 0, 0
local function check(name, condition, detail)
    total = total + 1
    if condition then
        print('ok   ' .. name)
    else
        failures = failures + 1
        print('FAIL ' .. name .. (detail and ('  -> ' .. tostring(detail)) or ''))
    end
end

-- grid ---------------------------------------------------------------------
layouter.initialize()
check('column width', layouter.COLUMN_WIDTH == layouter._helpers.math_round(WINDOW_WIDTH / layouter.COLUMNS),
    layouter.COLUMN_WIDTH)
check('COLUMN6 shortcut', layouter.COLUMN6 == layouter.COLUMN_WIDTH * 6)
check('ROW16 shortcut', layouter.ROW16 == layouter.ROW_HEIGHT * 16)

-- keys ---------------------------------------------------------------------
layouter.reset()
check('add returns key', layouter.add('Start game') == 'startgame')
check('duplicate content gets unique key', layouter.add('Start game') == 'startgame2')
check('spacer gets a key', layouter.add() == 'text')
check('second spacer key differs', layouter.add() == 'text2')
check('image without key does not crash',
    pcall(layouter.add, {content = {getDimensions = function() return 64, 64 end}, type = 'image', x = 0, y = 0}))

-- auto spacing without x/y (used to be an arithmetic-on-boolean crash) ------
layouter.reset()
layouter.add('one')
layouter.add('two')
check('spacing=auto without x/y', pcall(layouter.prepare, {spacing = 'auto'}))

-- prepare merges with previous state instead of overriding it --------------
layouter.reset()
layouter.add('one')
layouter.add('two')
layouter.prepare({x = 100, y = 50, direction = 'vertical', spacing = 'auto'})
layouter.prepare({direction = 'horizontal'})
check('prepare keeps previous x', layouter._previous.x == 100, layouter._previous.x)
check('prepare applies new direction', layouter._previous.direction == 'horizontal', layouter._previous.direction)
check('horizontal row stays on one line', layouter._layout[1].y == layouter._layout[2].y)

-- horizontal elements stay inside the window -------------------------------
layouter.reset()
for index = 1, 4 do layouter.add('button ' .. index) end
layouter.prepare({x = layouter.COLUMN6, y = layouter.ROW4, direction = 'horizontal', spacing = 'auto'})
local last = layouter._layout[#layouter._layout]
check('horizontal layout does not overflow', last.x + last.width <= WINDOW_WIDTH, last.x + last.width)

-- horizontal vs vertical layout --------------------------------------------
local PADDING = 10

layouter.reset()
for index = 1, 3 do layouter.add('element ' .. index) end
layouter.prepare({x = 0, y = 0, direction = 'vertical', spacing = 'auto', padding = PADDING})
local vertical = layouter._layout
local expected_height = WINDOW_HEIGHT / 3 - PADDING * 2
check('vertical: full width minus padding',
    vertical[1].width == WINDOW_WIDTH - PADDING * 2, vertical[1].width)
check('vertical: height is the available height split per element',
    math.abs(vertical[1].height - expected_height) < 0.001, vertical[1].height)
check('vertical: all elements share one column',
    vertical[1].x == vertical[2].x and vertical[2].x == vertical[3].x, vertical[1].x)
check('vertical: elements are stacked downwards',
    vertical[1].y < vertical[2].y and vertical[2].y < vertical[3].y)
check('vertical: elements do not overlap',
    vertical[2].y >= vertical[1].y + vertical[1].height and vertical[3].y >= vertical[2].y + vertical[2].height)
check('vertical: stack fits the window',
    vertical[3].y + vertical[3].height <= WINDOW_HEIGHT, vertical[3].y + vertical[3].height)
check('vertical: first element starts one padding in',
    vertical[1].x == PADDING and vertical[1].y == PADDING, vertical[1].x .. ',' .. vertical[1].y)

layouter.reset()
for index = 1, 3 do layouter.add('element ' .. index) end
layouter.prepare({x = 0, y = 0, direction = 'horizontal', spacing = 'auto', padding = PADDING})
local horizontal = layouter._layout
local expected_width = WINDOW_WIDTH / 3 - PADDING * 2
check('horizontal: width is the available width split per element',
    math.abs(horizontal[1].width - expected_width) < 0.001, horizontal[1].width)
check('horizontal: height is one line plus padding',
    horizontal[1].height == layouter.font:getHeight() + PADDING * 2, horizontal[1].height)
check('horizontal: all elements share one row',
    horizontal[1].y == horizontal[2].y and horizontal[2].y == horizontal[3].y, horizontal[1].y)
check('horizontal: elements advance to the right',
    horizontal[1].x < horizontal[2].x and horizontal[2].x < horizontal[3].x)
check('horizontal: elements do not overlap',
    horizontal[2].x >= horizontal[1].x + horizontal[1].width
    and horizontal[3].x >= horizontal[2].x + horizontal[2].width)
check('horizontal: row fits the window',
    horizontal[3].x + horizontal[3].width <= WINDOW_WIDTH, horizontal[3].x + horizontal[3].width)
check('horizontal: row sits at the layout y, not offset by padding',
    horizontal[1].y == 0, horizontal[1].y)

-- the two directions are transpositions of each other
check('directions differ: vertical is taller than wide, horizontal is wider than tall',
    vertical[1].height < horizontal[1].width and horizontal[1].height < vertical[1].width)
check('vertical spreads on y only', vertical[1].x == vertical[3].x and vertical[1].y ~= vertical[3].y)
check('horizontal spreads on x only', horizontal[1].y == horizontal[3].y and horizontal[1].x ~= horizontal[3].x)

-- switching direction on the same elements reflows them
layouter.prepare({direction = 'vertical'})
check('switching back to vertical restacks the same elements',
    layouter._layout[1].x == layouter._layout[3].x and layouter._layout[1].y ~= layouter._layout[3].y)
check('switching direction keeps the element count', #layouter._layout == 3, #layouter._layout)

-- non-auto spacing starts at x/y and runs to the window edge
layouter.reset()
for index = 1, 2 do layouter.add('element ' .. index) end
layouter.prepare({x = 200, y = 100, direction = 'horizontal', padding = PADDING})
local offset = layouter._layout
check('horizontal: offset row still fits the window',
    offset[2].x + offset[2].width <= WINDOW_WIDTH, offset[2].x + offset[2].width)
check('horizontal: row starts at the layout x', offset[1].x == 200 + PADDING, offset[1].x)
check('horizontal: row sits at the layout y', offset[1].y == 100, offset[1].y)

layouter.reset()
for index = 1, 2 do layouter.add('element ' .. index) end
layouter.prepare({x = 200, y = 100, direction = 'vertical', padding = PADDING})
offset = layouter._layout
check('vertical: offset column still fits the window',
    offset[2].y + offset[2].height <= WINDOW_HEIGHT, offset[2].y + offset[2].height)
check('vertical: column starts at the layout x/y',
    offset[1].x == 200 + PADDING and offset[1].y == 100 + PADDING, offset[1].x .. ',' .. offset[1].y)

-- manually positioned elements do not consume auto space -------------------
layouter.reset()
layouter.add({content = 'fixed', x = 10, y = 10})
layouter.add('auto one')
layouter.add('auto two')
layouter.prepare({x = 0, y = 0, direction = 'vertical'})
check('auto elements split space between themselves',
    math.abs(layouter._layout[2].height - (WINDOW_HEIGHT / 2 - 20)) < 0.001, layouter._layout[2].height)
check('fixed element keeps its position', layouter._layout[1].x == 10 and layouter._layout[1].y == 10)
check('fixed element got measured', layouter._layout[1].width > 0 and layouter._layout[1].height > 0)

-- partially positioned element gets the missing coordinate -----------------
layouter.reset()
layouter.add({content = 'half', x = 25})
layouter.prepare({x = 0, y = 77, direction = 'vertical'})
check('missing y filled from layout', layouter._layout[1].y == 77, layouter._layout[1].y)
check('partially positioned element has size', layouter._layout[1].width ~= nil)

-- remove / replace ---------------------------------------------------------
layouter.reset()
layouter.add('alpha')
-- two elements deliberately sharing one key: removal must not skip the second
layouter.add({content = 'beta', key = 'beta'})
layouter.add({content = 'beta', key = 'beta'})
layouter.prepare({x = 0, y = 0})
layouter.remove('beta')
check('remove deletes every match', #layouter.elements == 1, #layouter.elements)
check('remove refreshes the drawn layout', #layouter._layout == 1, #layouter._layout)
layouter.replace('alpha', 'Currently does nothing.')
check('replace keeps the key', layouter.elements[1].key == 'alpha', layouter.elements[1].key)
check('replace swaps the content', layouter.elements[1].content == 'Currently does nothing.')

-- real vertical centering --------------------------------------------------
local centered = {y = 100, height = 100, width = 400, content = 'x', font = newFont(20)}
check('single line is centered', layouter._helpers.text_y(centered) == 100 + (100 - 20) / 2,
    layouter._helpers.text_y(centered))
local wrapped = {y = 0, height = 100, width = 40, content = string.rep('x', 12), font = newFont(20)}
check('wrapped text is centered as a block', layouter._helpers.text_y(wrapped) == (100 - 3 * 20) / 2,
    layouter._helpers.text_y(wrapped))

-- hit testing --------------------------------------------------------------
check('is_inside handles missing size', layouter._helpers.is_inside({x = 0, y = 0}, 5, 5) == false)
check('is_inside hits', layouter._helpers.is_inside({x = 0, y = 0, width = 10, height = 10}, 5, 5))
check('is_inside misses', layouter._helpers.is_inside({x = 0, y = 0, width = 10, height = 10}, 50, 5) == false)

-- grid-native element placement --------------------------------------------
layouter.reset()
layouter.add({content = 'grid', column = 3, row = 2, column_span = 4, row_span = 2})
layouter.add({content = 'grid origin', column = 0, row = 0, key = 'origin'})
layouter.prepare({x = 0, y = 0})
local grid_element = layouter._layout[1]
check('column matches the COLUMNn constant', grid_element.x == layouter.COLUMN3, grid_element.x)
check('row matches the ROWn constant', grid_element.y == layouter.ROW2, grid_element.y)
check('column_span maps to width', grid_element.width == layouter.COLUMN_WIDTH * 4, grid_element.width)
check('row_span maps to height', grid_element.height == layouter.ROW_HEIGHT * 2, grid_element.height)
check('column/row 0 is the top left corner', layouter._layout[2].x == 0 and layouter._layout[2].y == 0)

-- resize -------------------------------------------------------------------
layouter.resize(1600, 1200)
check('resize recalculates columns',
    layouter.COLUMN_WIDTH == layouter._helpers.math_round(1600 / layouter.COLUMNS), layouter.COLUMN_WIDTH)
check('resize recalculates rows',
    layouter.ROW_HEIGHT == layouter._helpers.math_round(1200 / layouter.ROWS), layouter.ROW_HEIGHT)

-- draw / mouse smoke test --------------------------------------------------
layouter.reset()
local clicked = false
layouter.add({content = 'Quit', type = 'button', callback = function() clicked = true end, key = 'quit'})
layouter.add({content = {getDimensions = function() return 64, 64 end}, type = 'image', key = 'logo'})
layouter.prepare({x = 0, y = 0, direction = 'vertical', spacing = 'auto'})
check('draw runs', pcall(layouter.draw))
local button = layouter._layout[1]
layouter.processMouse(button.x + 1, button.y + 1, 1)
check('button callback fires', clicked)
clicked = false
layouter.processMouse(button.x + 1, button.y + 1, 2)
check('other mouse buttons ignored', clicked == false)

print(string.format('\n%d/%d passed', total - failures, total))
os.exit(failures == 0 and 0 or 1)
