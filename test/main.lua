package.path = '../?.lua;../?/init.lua;' .. package.path
local layouter = require '..layouter'

local direction = 'vertical'
local overflow = 'none'
local extra = 0

local function build()
    layouter.reset()
    -- manually placed via the grid: stays put in both directions
    layouter.add({content = 'Your special layout', column = 0, row = 1, column_span = 24,
        font = love.graphics.newFont(30)})
    layouter.add({content = 'SPACE = direction, W = wrap, A = add, R = remove, D = debug grid',
        column = 0, row = 14, column_span = 24})
    -- automatically laid out: these are what direction/spacing/padding act on
    -- the menu group is one row/column of its own, more elements can be added into it later
    layouter.addTo('menu', {content = 'Start game', type = 'button',
        callback = function() print('start game') end})
    layouter.addTo('menu', {content = 'Credits', type = 'button',
        callback = function() print('credits') end})
    layouter.addTo('menu', {content = 'Quit', type = 'button', callback = function() love.event.quit() end})
    for number = 1, extra do
        layouter.addTo('menu', {content = 'Extra ' .. number, type = 'button'})
    end
    layouter.prepare({x = layouter.COLUMN6, y = layouter.ROW5, direction = direction, spacing = 'auto',
        overflow = overflow, min_width = 150})
end

function love.load()
    love.window.setMode(800, 600, {resizable = true})
    layouter.initialize({background = {13, 46, 63}, color = {255, 255, 255}})
    build()
end

function love.draw()
    layouter.draw()
end

function love.mousepressed(x, y, mouse_button, is_touch)
    layouter.processMouse(x, y, mouse_button, is_touch)
end

function love.keypressed(key)
    if key == 'space' then
        -- only the direction changes, x/y/spacing/padding are kept from the previous prepare
        direction = direction == 'vertical' and 'horizontal' or 'vertical'
        layouter.prepare({direction = direction})
    elseif key == 'w' then
        -- wrapping keeps elements above min_width/min_height by using more rows/columns
        overflow = overflow == 'none' and 'wrap' or 'none'
        layouter.prepare({overflow = overflow})
    elseif key == 'a' then
        -- new element goes into the existing menu row/column
        extra = extra + 1
        layouter.addTo('menu', {content = 'Extra ' .. extra, type = 'button'})
        layouter.prepare()
    elseif key == 'r' then
        -- removes the last added element from the menu row/column, remove() reflows on its own
        if extra > 0 then
            layouter.remove('extra' .. extra)
            extra = extra - 1
        end
    elseif key == 'd' then
        layouter.debug = not layouter.debug
    elseif key == 'escape' then
        love.event.quit()
    end
end

function love.resize(width, height)
    -- the grid shortcuts depend on the window size, so the elements are rebuilt
    layouter.resize(width, height)
    build()
end
