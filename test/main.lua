local layouter = require 'layouter'

local direction = 'vertical'

local function build()
    layouter.reset()
    -- manually placed via the grid: stays put in both directions
    layouter.add({content = 'Your special layout', column = 0, row = 1, column_span = 24,
        font = love.graphics.newFont(30)})
    layouter.add({content = 'press SPACE to switch direction, D for the debug grid, resize the window freely',
        column = 0, row = 14, column_span = 24})
    -- automatically laid out: these are what direction/spacing/padding act on
    layouter.add({content = 'Start game', type = 'button',
        callback = function() print('start game') end})
    layouter.add({content = 'Credits', type = 'button',
        callback = function() print('credits') end})
    layouter.add({content = 'Quit', type = 'button', callback = function() love.event.quit() end})
    layouter.prepare({x = layouter.COLUMN6, y = layouter.ROW5, direction = direction, spacing = 'auto'})
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
