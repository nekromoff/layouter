# Layouter

Layouter is a simple **UI grid layout library** for LÖVE 2D game engine.

It currently supports these element types:

- text (including spacer = blank text)
- text button
- image

## Usage

### 1. Include layouter
```
layouter = require 'layouter'
```

### 2. Initialize layouter
Defaults=15px, white background, black color, debug disabled:
```
layouter.initialize()
```
or with a custom look (font=20px, background=black, color=white, debug mode enabled=draw grid):
```
layouter.initialize({font=love.graphics.newFont(20), background={0,0,0}, color={255,255,255}, debug=true})
```

### 3. Add elements to your layout
#### Text element
```
layouter.add('Hello world!')
```
#### Text element with options
```
layouter.add({content = 'Second text paragraph', font = love.graphics.newFont(50), color = {13, 46, 63}})
```
#### Spacer (blank paragraph)
```
layouter.add()
```
#### Image with required custom key (key can be used to replace or remove it later)
```
layouter.add({content = love.graphics.newImage('logo.png'), type = 'image', key = 'logo'})
```
#### Button
```
layouter.add({content = 'Start game', type = 'button', callback = function() startGame() end})
```
#### Button that replaces itself on a click with a text
Note the automatically assigned key `eastereggs` that is created from the text.
```
layouter.add({content = '* easter! Eggs $@', type = 'button', callback = function() layouter.replace('eastereggs', 'Currently does nothing.') end})
```

### 4. Prepare your layout
Set where to draw your elements, how they should be aligned horizontaly or vertically and if auto spacing (based on number of elements) should be done.
x=position X, y=position Y, direction=`horizontal` or `vertical`, spacing=`auto` for automatical centering, optionally also padding=(in pixels)
```
layouter.prepare({x = layouter.COLUMN6, y = layouter.ROW4, direction = 'vertical', spacing = 'auto'})
```

### 5.Draw your layout
```
function love.draw()
	layouter.draw()
end
```

### 6. Process mouse clicks for buttons
This functions needs to be called to enable interaction for buttons.
```
function love.mousepressed(x, y, mouse_button, is_touch)
	layouter.processMouse(x, y, mouse_button, is_touch)
end
```
