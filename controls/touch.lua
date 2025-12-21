-- controls/touch.lua
local M = {}

-- ============================================================
-- KONFIGURACJA (Dotykowa)
-- ============================================================
local DPAD_AREA_SIZE = 180
local ACTION_BUTTON_SIZE = 90
local KNOB_RADIUS_RATIO = 3.5
local MOVE_THRESHOLD = 20
local DIRECTION_RATIO = 0.3
-- PADDING i UI_SCALE są przekazywane z zewnątrz w kontekście

-- ============================================================
-- DEFINICJA PRZYCISKÓW
-- ============================================================

function M.defineButtons(w, h, ctx)
    local buttons = {}
    local touchControls = ctx.touchControls
    
    local s_iconSize = ctx.ICON_SIZE * ctx.UI_SCALE
    local s_padding = ctx.PADDING * ctx.UI_SCALE
    local s_yOffset = ctx.HUD_Y_OFFSET * ctx.UI_SCALE

    local startX = w * ctx.HUD_START_X_RATIO
    local startY = h * ctx.HUD_START_Y_RATIO

    if ctx.HUD_START_X_RATIO < 0.5 then startX = startX + s_padding
    else startX = startX - s_iconSize - s_padding end

    if ctx.HUD_START_Y_RATIO < 0.5 then startY = startY + s_yOffset
    else startY = startY - s_iconSize - s_yOffset end

    local currentX = startX
    local commonY = startY

    -- 1. Options icon
    table.insert(buttons, {
        name = "options", type = "icon_btn",
        x = currentX, y = commonY, w = s_iconSize, h = s_iconSize,
        action = "open_menu"
    })
    currentX = currentX + s_iconSize + s_padding

    -- 2. Inventory icon
    table.insert(buttons, {
        name = "inventory", type = "icon_btn",
        x = currentX, y = commonY, w = s_iconSize, h = s_iconSize,
        action = "toggle_inventory"
    })
    currentX = currentX + s_iconSize + s_padding

    -- 3. Leveling / Stats
    table.insert(buttons, {
        name = "stats", type = "icon_btn",
        x = currentX, y = commonY, w = s_iconSize, h = s_iconSize,
        action = "toggle_stats"
    })

    -- Mobile controls only when isMobile == true
    if ctx.isMobile then
        local buttonSize = ACTION_BUTTON_SIZE * ctx.UI_SCALE
        local dpadAreaSize = DPAD_AREA_SIZE * ctx.UI_SCALE
        local padding = ctx.PADDING * ctx.UI_SCALE

        -- Dpad area
        table.insert(buttons, {
            name = "DpadArea", type = "dpad",
            x = padding, y = h - dpadAreaSize - padding,
            w = dpadAreaSize, h = dpadAreaSize, action = "move"
        })

        -- Action button
        table.insert(buttons, {
            name = "ActionB", type = "action_btn",
            x = w - buttonSize - padding, y = h - buttonSize - padding,
            w = buttonSize, h = buttonSize, action = "reload"
        })
    end

    touchControls.buttons = buttons
    touchControls.currentScale = ctx.UI_SCALE
end

function M.checkButton(x, y, touchControls)
    if not touchControls.buttons then return nil end
    local nx, ny = x, y
    for _, btn in ipairs(touchControls.buttons) do
        if nx >= btn.x and nx <= btn.x + btn.w and ny >= btn.y and ny <= btn.y + btn.h then
            return btn
        end
    end
    return nil
end

-- ============================================================
-- RYSOWANIE
-- ============================================================
function M.draw(game, ctx)
    -- Rozpakowanie kontekstu
    local touchControls = ctx.touchControls
    local activeTouches = ctx.activeTouches
    local love = ctx.love
    local optionsIcon = ctx.images.options
    local inventoryIcon = ctx.images.inventory
    local statsIcon = ctx.images.stats
    local normalizeCoords = ctx.normalizeCoords
    
    if not touchControls.buttons then return end

    love.graphics.push()
    love.graphics.origin()

    local mx, my = love.mouse.getPosition()
    local nmx, nmy = normalizeCoords(mx, my)
    local hitBtn = M.checkButton(nmx, nmy, touchControls)

    for _, button in ipairs(touchControls.buttons) do
        local isPressed = false
        local touch_for_button = nil

        for _, t in pairs(activeTouches) do
            if (t.type == 'button' and t.name == button.name) or (button.name == "DpadArea" and t.type == 'dpad') then
                isPressed = true
                touch_for_button = t
                break
            end
        end

        if button.type == "icon_btn" then
            -- Wybór ikony
            local icon = nil
            local label = "?"
            if button.name == "options" then 
                icon = optionsIcon; label = "O"
            elseif button.name == "inventory" then 
                icon = inventoryIcon; label = "I"
            elseif button.name == "stats" then 
                icon = statsIcon; label = "+"
            end

            love.graphics.setColor(1, 1, 1, 1)
            if icon and icon.getWidth then
                love.graphics.draw(icon, button.x, button.y, 0, button.w / icon:getWidth(), button.h / icon:getHeight())
            else
                -- Fallback: prostokąt z literą
                love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
                love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 4, 4)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(label, button.x, button.y + button.h/2 - 8, button.w, "center")
            end

            -- Żółta ramka na dotyk
            if isPressed then
                love.graphics.setColor(1, 1, 0, 1)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 4, 4)
                love.graphics.setLineWidth(1)
            end

            -- === CZERWONA KROPKA POWIADOMIENIA DLA STATS ===
            if button.name == "stats" and game and game.leveling and game.leveling.levelUpAvailable then
                local dotSize = 10
                local dotX = button.x + 6 + button.w - dotSize + 2
                local dotY = button.y + 2
                
                -- Kropka
                love.graphics.setColor(1, 0, 0, 1)
                love.graphics.circle("fill", dotX, dotY, dotSize/2)
                
                -- Obwódka kropki (dla lepszej widoczności)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", dotX, dotY, dotSize/2)
            end

        elseif button.type == "dpad" then
             local dpad = touch_for_button
             local centerX = button.x + button.w / 2
             local centerY = button.y + button.h / 2
             local knobRadius = button.w / KNOB_RADIUS_RATIO
 
             love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
             love.graphics.circle("fill", centerX, centerY, button.w/2)
 
             local knobX, knobY = centerX, centerY
             if dpad then
                 knobX = dpad.knobX or centerX
                 knobY = dpad.knobY or centerY
                 love.graphics.setColor(0.8, 0.8, 0.8, 0.9)
             else
                 love.graphics.setColor(0.4, 0.4, 0.4, 0.7)
             end
             love.graphics.circle("fill", knobX, knobY, knobRadius)

        elseif button.type == "action_btn" then
            local color = {0.2, 0.2, 0.2, 0.7}
            if isPressed then color = {0.8, 0.8, 0.8, 0.9} end

            love.graphics.setColor(color)
            love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 10, 10)
            love.graphics.setColor(1,1,1,1)
            love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 10, 10)
            love.graphics.printf("R", button.x, button.y + button.h/2 - 10, button.w, "center")
        end
    end

    love.graphics.pop()
end

-- ============================================================
-- OBSŁUGA ZDARZEŃ DOTYKU
-- ============================================================
function M.touchpressed(id, x, y, pressure, game, ctx)
    local game = ctx.ensureGame(game)
    if not game then return end
    
    local love = ctx.love
    local activeTouches = ctx.activeTouches
    local normalizeCoords = ctx.normalizeCoords

    if not ctx.controlsDefined then ctx.refreshControls() end
    local nx, ny = normalizeCoords(x, y)

    if game.state == "menu" or game.state == "nick_input" then
        if game.menu and game.menu.mousepressed then game.menu:mousepressed(nx, ny, 1, game) end
        return
    end

    -- Leveling priority (only if open)
    if game.leveling and game.leveling.isOpen and game.leveling.mousepressed then
        if game.leveling:mousepressed(nx, ny, 1) then
            activeTouches[id] = { id = id, type = 'leveling' }
            return
        end
    end

    if game.state ~= "playing" then return end

    local button = M.checkButton(nx, ny, ctx.touchControls)

    if button and button.type == "dpad" then
        local centerX = button.x + button.w / 2
        local centerY = button.y + button.h / 2
        activeTouches[id] = {
            id = id, type = 'dpad',
            initialX = centerX, initialY = centerY,
            knobX = nx, knobY = ny,
            centerX = centerX, centerY = centerY,
            maxRadius = button.w / 2
        }
        return
    end

    if button and button.type == "action_btn" then
        activeTouches[id] = { id = id, type = 'button', name = button.name, pressedTime = love.timer.getTime() } 
        if game.player and game.player.keypressed then game.player:keypressed('r') end
        return
    end

    if button and (button.type == "icon_btn") then
        activeTouches[id] = { 
            id = id, type = 'button', name = button.name,
            pressedTime = love.timer.getTime() 
        }
        return
    end

    if not button then
        activeTouches[id] = { id = id, type = 'camera', initialX = nx, initialY = ny, sensitivity = ctx.CAMERA_SENSITIVITY }
        if game.player and game.player.mousepressed then game.player:mousepressed(nx, ny, 1) end
        return
    end
end

function M.touchmoved(id, x, y, dx, dy, pressure, game, ctx)
    local game = ctx.ensureGame(game)
    if not game then return end
    if game.state ~= "playing" then return end

    local activeTouches = ctx.activeTouches
    local normalizeCoords = ctx.normalizeCoords
    local math = ctx.math
    local love = ctx.love

    local touch = activeTouches[id]
    if not touch then return end
    if touch.type == 'leveling' then return end

    if game.inventory and game.inventory.isOpen and game.inventory.touchmoved and touch.type ~= 'button' then
        game.inventory:touchmoved(id, x, y, pressure)
        return
    end

    local nx, ny = normalizeCoords(x, y)

    if touch.type == 'dpad' then
        local centerX = touch.centerX or touch.initialX
        local centerY = touch.centerY or touch.initialY
        local maxRadius = touch.maxRadius or (DPAD_AREA_SIZE * ctx.UI_SCALE / 2)

        local diffX = nx - centerX
        local diffY = ny - centerY
        local distance = math.sqrt(diffX*diffX + diffY*diffY)
        if distance > maxRadius then
            local scale = maxRadius / distance
            diffX = diffX * scale
            diffY = diffY * scale
            distance = maxRadius
        end

        touch.knobX = centerX + diffX
        touch.knobY = centerY + diffY
        touch.dx = diffX
        touch.dy = diffY

        if game.player then
            game.player.moveLeft = false; game.player.moveRight = false
            game.player.moveUp = false; game.player.moveDown = false
            if distance > MOVE_THRESHOLD then
                local normX = diffX / distance
                local normY = diffY / distance
                if normX < -DIRECTION_RATIO then game.player.moveLeft = true end
                if normX > DIRECTION_RATIO then game.player.moveRight = true end
                if normY < -DIRECTION_RATIO then game.player.moveUp = true end
                if normY > DIRECTION_RATIO then game.player.moveDown = true end
            end
        end
    elseif touch.type == 'camera' then
        if game.player and game.player.rotate then
            local sensitivity = touch.sensitivity or ctx.CAMERA_SENSITIVITY
            local adjustedDx = dx
            if math.abs(dx) <= 1 then adjustedDx = dx * love.graphics.getWidth() end
            game.player:rotate(adjustedDx * sensitivity)
        end
    end
end

function M.touchreleased(id, x, y, pressure, game, ctx)
    local game = ctx.ensureGame(game)
    if not game then return end
    
    local activeTouches = ctx.activeTouches
    local love = ctx.love
    local normalizeCoords = ctx.normalizeCoords
    
    if game.state ~= "playing" then activeTouches[id] = nil; return end

    local touch = activeTouches[id]
    if not touch then return end

    if touch.type == 'leveling' then
        activeTouches[id] = nil
        return
    end
    
    if touch.type == 'button' then
        local releaseTime = love.timer.getTime()
        local pressDuration = releaseTime - (touch.pressedTime or 0)
        local isTap = pressDuration < 0.3
        
        if isTap and (touch.name == "inventory" or touch.name == "options" or touch.name == "stats") then
            local nx, ny = normalizeCoords(x, y)
            local hit = M.checkButton(nx, ny, ctx.touchControls)
            if hit and hit.name == touch.name then 
                ctx.handleHudAction(hit, game) 
            end
        end

        activeTouches[id] = nil
        return
    end

    if game.inventory and game.inventory.isOpen and game.inventory.touchreleased then
        game.inventory:touchreleased(id, x, y, pressure)
        activeTouches[id] = nil
        return
    end

    if touch.type == "dpad" and game.player then
        game.player.moveLeft = false; game.player.moveRight = false
        game.player.moveUp = false; game.player.moveDown = false
    end

    activeTouches[id] = nil
end

local function applyDpadMovement(game, ctx)
    if not game then return end
    local moveX, moveY = 0, 0
    local math = ctx.math
    local activeTouches = ctx.activeTouches
    
    for _, touch in pairs(activeTouches) do
        if touch.type == "dpad" then
            local dx = touch.dx or (touch.knobX and (touch.knobX - (touch.centerX or touch.initialX)) or 0)
            local dy = touch.dy or (touch.knobY and (touch.knobY - (touch.centerY or touch.initialY)) or 0)
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > MOVE_THRESHOLD then
                local nx = dx / dist
                local ny = dy / dist
                if math.abs(ny) > DIRECTION_RATIO then moveY = moveY + ny end
                if math.abs(nx) > DIRECTION_RATIO then moveX = moveX + nx end
            end
        end
    end
    if game.player and game.player.moveInput then
        game.player:moveInput(moveX, moveY)
    end
end

function M.update(dt, game, ctx)
    local game = ctx.ensureGame(game)
    if not game then return end
    -- refreshControls wywoływane w init.lua przed wywołaniem tego update'a
    applyDpadMovement(game, ctx)
end

return M