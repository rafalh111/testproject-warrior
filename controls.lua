local M = {}
local math = math or {}
local love = love or {}

-- ============================================================
-- KONFIGURACJA STEROWANIA I HUD
-- ============================================================

-- DOTYKOWE (D-Pad i Akcja)
local DPAD_AREA_SIZE = 180    -- Rozmiar obszaru D-Pada
local ACTION_BUTTON_SIZE = 90 -- Rozmiar przycisków akcji (dolny róg)
local KNOB_RADIUS_RATIO = 3.5 -- Współczynnik dla promienia gałki
local MOVE_THRESHOLD = 20     -- Minimalny ruch gałki do aktywacji kierunku (px)
local DIRECTION_RATIO = 0.3   -- Proporcja wektora do aktywacji kierunku
local CAMERA_SENSITIVITY = 0.5-- Czułość obracania kamerą

-- WSPÓLNE/HUD (Ikony Options/Inventory)
local PADDING = 20            -- Bazowy odstęp od krawędzi ekranu
local UI_SCALE = 1.0          -- Bazowa skala UI
local ICON_SIZE = 32          -- Wielkość ikon HUD (px)
local HUD_Y_OFFSET = 80       -- Odsunięcie ikon od górnej krawędzi
local HUD_START_X_RATIO = 0.0 -- Pozycja X dla ikon (0.0 = lewa, 1.0 = prawa)
local HUD_START_Y_RATIO = 0.0 -- Pozycja Y dla ikon (0.0 = góra, 1.0 = dół)


-- ============================================================
-- ZMIENNE WEWNĘTRZNE I ZASOBY
-- ============================================================

local menuRef = nil
local activeTouches = {}
local controlsDefined = false 
local touchControls = {}
local isMobile = false

-- Zasoby graficzne dla HUD
local optionsIcon = nil
local inventoryIcon = nil


------------------------------------------------------------
-- FUNKCJE POMOCNICZE
------------------------------------------------------------

local function ensureGame(game)
    game = game or _G.game
    if not game then
        print("[ERROR] controls.lua: game == nil")
        return nil
    end
    return game
end

-- Normalizuje koordynaty dotyku/myszy do pikseli ekranu
local function normalizeCoords(x, y)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local osname = love.system and love.system.getOS() or "Unknown"
    local isMobileOS = (osname == "Android" or osname == "iOS")

    if x >= 0 and x <= 1 and y >= 0 and y <= 1 and isMobileOS then
        return x * screenW, y * screenH
    end

    return x, y
end


------------------------------------------------------------
-- DEFINICJA I GENEROWANIE PRZYCISKÓW (ZINTEGROWANE)
------------------------------------------------------------

function touchControls.defineButtons(w, h)
    local buttons = {}
    
    -- Obliczenia dla ikon HUD (Options/Inventory)
    local s_iconSize = ICON_SIZE * UI_SCALE
    local s_padding = PADDING * UI_SCALE
    local s_yOffset = HUD_Y_OFFSET * UI_SCALE

    local startX = w * HUD_START_X_RATIO
    local startY = h * HUD_START_Y_RATIO
    
    if HUD_START_X_RATIO < 0.5 then startX = startX + s_padding
    else startX = startX - s_iconSize - s_padding end
    
    if HUD_START_Y_RATIO < 0.5 then startY = startY + s_yOffset
    else startY = startY - s_iconSize - s_yOffset end

    local currentX = startX
    local commonY = startY

    -- 1. PRZYCISK OPCJE
    table.insert(buttons, {
        name = "options", type = "icon_btn", 
        x = currentX, y = commonY, w = s_iconSize, h = s_iconSize, action = "open_menu"
    })
    currentX = currentX + s_iconSize + s_padding

    -- 2. PRZYCISK INVENTORY
    table.insert(buttons, {
        name = "inventory", type = "icon_btn",
        x = currentX, y = commonY, w = s_iconSize, h = s_iconSize, action = "toggle_inventory"
    })
    
    -- Obliczenia dla elementów mobilnych (D-Pad i Akcja)
    local buttonSize = ACTION_BUTTON_SIZE * UI_SCALE
    local dpadAreaSize = DPAD_AREA_SIZE * UI_SCALE
    local padding = PADDING * UI_SCALE

    -- 3. D-Pad w lewym dolnym rogu
    table.insert(buttons, { 
        name = "DpadArea", type = "dpad",
        x = padding, y = h - dpadAreaSize - padding, w = dpadAreaSize, h = dpadAreaSize, action = "move" 
    })
    
    -- 4. Przycisk Akcji w prawym dolnym rogu
    table.insert(buttons, { 
        name = "ActionB", type = "action_btn",
        x = w - buttonSize - padding, y = h - buttonSize - padding, w = buttonSize, h = buttonSize, action = "inventory" 
    })
    
    touchControls.buttons = buttons
    touchControls.currentScale = UI_SCALE
    controlsDefined = true
end

-- Sprawdza, czy koordynaty (x, y) trafiają w któryś z przycisków
function touchControls.checkButton(x, y)
    if not controlsDefined or not touchControls.buttons then return nil end
    
    local nx, ny = normalizeCoords(x, y) 

    for _, button in ipairs(touchControls.buttons) do
        if nx >= button.x and nx <= button.x + button.w and
           ny >= button.y and ny <= button.y + button.h then
            return button
        end
    end
    return nil
end

-- Rysowanie wszystkich elementów
function touchControls.draw(game)
    if not controlsDefined then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local currentScale = touchControls.currentScale or 1.0
    
    love.graphics.push()
    love.graphics.origin()

    -- Wyszukiwanie klikniętego przycisku (dla hovera na PC)
    local mx, my = love.mouse.getPosition() 
    local hitBtn = touchControls.checkButton(mx, my)

    for _, button in ipairs(touchControls.buttons) do
        local isPressed = false
        local touch_for_button = nil
        
        -- Wyszukiwanie dotyku przypisanego do przycisku
        for _, touch in pairs(activeTouches) do
            if (touch.type == 'button' and touch.name == button.name) or
               (button.name == "DpadArea" and touch.type == 'dpad') then
                isPressed = true
                touch_for_button = touch
                break
            end
        end

        -- RYSOWANIE IKON HUD (Options/Inventory)
        if button.type == "icon_btn" then
            local icon = (button.name == "options" and optionsIcon) or (button.name == "inventory" and inventoryIcon)

            love.graphics.setColor(1, 1, 1)
            if icon then
                love.graphics.draw(
                    icon, 
                    button.x, button.y, 0, 
                    button.w / icon:getWidth(), button.h / icon:getHeight()
                )
            end
            
            -- Hover na PC lub aktywny stan mobilny
            if hitBtn == button or isPressed then
                love.graphics.setColor(1, 1, 0)
                love.graphics.setLineWidth(math.max(1, 2 * currentScale))
                love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
                love.graphics.setLineWidth(1)
            end


        -- RYSOWANIE D-PADA
        elseif button.type == "dpad" then
            local dpad = touch_for_button
            local centerX = button.x + button.w/2
            local centerY = button.y + button.h/2
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


        -- RYSOWANIE PRZYCISKU AKCJI
        elseif button.type == "action_btn" then
            local color = {0.2, 0.2, 0.2, 0.7}
            if isPressed then color = {0.8, 0.8, 0.8, 0.9} end
            
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 10, 10)
            
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 10, 10)
            love.graphics.printf("E/R", button.x, button.y + button.h / 2 - 10, button.w, "center")
        end
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.pop()
    
    -- DEBUG
    if game and game.debugMode then
        love.graphics.setColor(1, 0, 0, 0.5)
        for _, btn in ipairs(touchControls.buttons) do 
            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        end
        love.graphics.setColor(1, 1, 1)
    end
end


-- Obsługa akcji klikniętych przycisków HUD
local function handleHudAction(hit, game)
    if hit and hit.type == "icon_btn" then
        if hit.action == "toggle_inventory" then
            if game.inventory and game.inventory.toggle then
                game.inventory:toggle()
                return true
            end
        elseif hit.action == "open_menu" then
            game.state = "menu"
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- PODSTAWOWE FUNKCJE I ŁADOWANIE
------------------------------------------------------------

function M.load()
    local osname = love.system and love.system.getOS() or "Unknown"
    isMobile = (osname == "Android" or osname == "iOS")
    
    optionsIcon = love.graphics.newImage("sprites/optionsicon.png")
    inventoryIcon = love.graphics.newImage("sprites/inventoryicon.png")
end

function M.init(menu)
    menuRef = menu
    M.load() -- Wczytanie ikon
    M.refreshControls()
end

function M.refreshControls()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    touchControls.defineButtons(w, h)
end

function M.MapKey(key)
    if not menuRef or not menuRef.keyBindings then return key end
    for action, boundKey in pairs(menuRef.keyBindings) do
        if boundKey == key then return action:lower() end
    end
    return key
end

function M.GetBoundKey(actionName)
    if not menuRef or not menuRef.keyBindings then return actionName:lower() end
    return menuRef.keyBindings[actionName]
end

function M.textinput(t, game)
    game = ensureGame(game)
    if not game then return end
    game.menu:textinput(t, game)
end

------------------------------------------------------------
-- KLAWIATURA
------------------------------------------------------------

-- M.keypressed pozostaje bez zmian


function M.keypressed(key, game)
    game = ensureGame(game)
    if not game then return end

    if key == "f3" then
        game.debugMode = not game.debugMode
        return
    end

    if game.state == "menu" or game.state == "nick_input" then 
        local action = game.menu:keypressed(key, game)
        if game.state == "menu" or game.state == "nick_input" then 
            if action == "start" and game.menu.nameEntered then 
                game.state = "playing"
                game.player.name = game.menu.playerNameInput
            elseif action == "quit" then
                love.event.quit()
            end
        end
        return 
    end
    
    if game.state == "playing" then
        if game.leveling.levelUpAvailable then
            game.leveling:keypressed(key)
            return
        end

        local mappedKey = M.MapKey(key)

        if game.inventory.isOpen then
            if mappedKey == "inventory" or key == "e" then
                game.inventory:toggle()
            else
                game.inventory:keypressed(key)
            end
            return
        end

        if key == "1" then game.quickslots.currentSlot = 1; game.quickslots:useCurrentSlot(); return end
        if key == "2" then game.quickslots.currentSlot = 2; game.quickslots:useCurrentSlot(); return end
        if key == "3" then game.quickslots.currentSlot = 3; game.quickslots:useCurrentSlot(); return end

        game.player:keypressed(key)

        if mappedKey == "inventory" or key == "e" then
            game.inventory:toggle()
        elseif key == "escape" then
            game.state = "menu"
        end

        if key == "return" then
            if game.arcade:interact(game.player) then
                game.snake:load()
                game.state = "snake"
            end
        end

    elseif game.state == "snake" then
        game.snake:keypressed(key)
        if key == "escape" then game.state = "playing" end
    end
end


------------------------------------------------------------
-- MYSZ / STRZELANIE / DRAG & DROP
------------------------------------------------------------

function M.mousepressed(x, y, button, game)
    game = ensureGame(game)
    if not game then return end
    
    if game.leveling.mousepressed(x, y, button) then return end

    -- 1. NAJPIERW OBSŁUGA NOWEGO HUD (usuwamy stare _G.buttonsUI)
    local hit = touchControls.checkButton(x, y)
    if handleHudAction(hit, game) then 
        return 
    end

    -- 2. DOPIERO POTEM DRAG & DROP W INVENTORY
    if game.state == "playing" and game.inventory.isOpen then
        game.inventory:mousepressed(x, y, button)
        return
    end

    if game.state == "menu" or game.state == "nick_input" then 
        game.menu:mousepressed(x, y, button, game)
        return 
    end

    if game.state == "playing" then
        game.player:mousepressed(x, y, button)
    end
end

function M.mousereleased(x, y, button, game)
    game = ensureGame(game)
    if not game then return end

    if game.state == "playing" and game.inventory.isOpen then
        game.inventory:mousereleased(x, y, button)
        return
    end
end

function M.wheelmoved(x, y, game)
    game = ensureGame(game)
    if not game then return end

    if game.state == "playing" and not game.inventory.isOpen then
        local delta = (y > 0 and -1) or (y < 0 and 1) or 0
        if delta ~= 0 then
            game.quickslots:changeSlot(delta)
        end
    end
end

------------------------------------------------------------
-- DOTYK
------------------------------------------------------------

function M.touchpressed(id, x, y, pressure, game)
    game = ensureGame(game)
    if not game then return end

    if not controlsDefined then M.refreshControls() end
    local nx, ny = normalizeCoords(x, y) 

    if game.state == "menu" or game.state == "nick_input" then
        game.menu:mousepressed(nx, ny, 1, game)
        return
    end

    local button = touchControls.checkButton(x, y) 

    -- 1. OBSŁUGA PRZYCISKÓW HUD (Options/Inventory)
    if handleHudAction(button, game) then 
        return 
    end

    -- 2. POTEM INVENTORY (Drag & Drop)
    if game.state == "playing" and game.inventory.isOpen then
        game.inventory:touchpressed(id, x, y, pressure) 
        return
    end
    
    if game.state ~= "playing" then return end
    
    -- 3. OBSŁUGA STEROWANIA MOBILNEGO (D-Pad / Akcja)
    if button and button.type == "dpad" then
        local centerX = button.x + button.w / 2
        local centerY = button.y + button.h / 2
        
        activeTouches[id] = { 
            id = id, type = 'dpad',
            initialX = nx, initialY = ny, 
            knobX = nx, knobY = ny,
            centerX = centerX, centerY = centerY, 
            maxRadius = button.w / 2 
        }

    elseif button and button.type == "action_btn" then
        activeTouches[id] = { id = id, type = 'button', name = button.name }

        -- Logika przycisku akcji
        if game.inventory and game.inventory.toggle then
            local isOpen = game.inventory.isOpen
            local weapon = game.inventory:getEquippedWeapon()
            
            if isOpen then
                game.inventory:toggle()
            elseif weapon and weapon.data.name == "Shotgun" then
                game.player:keypressed('r') 
            else
                game.inventory:toggle() 
            end
        end
    else
        -- 4. Dotyk poza przyciskami (kamera/strzał)
        activeTouches[id] = {
            id = id, type = 'camera',
            initialX = nx, initialY = ny,
            sensitivity = CAMERA_SENSITIVITY 
        }
        game.player:mousepressed(nx, ny, 1) 
    end
end

function M.touchmoved(id, x, y, dx, dy, pressure, game)
    game = ensureGame(game)
    if not game then return end

    if game.state ~= "playing" then return end

    if game.inventory.isOpen then
        game.inventory:touchmoved(id, x, y, pressure)
        return
    end
    
    local touch = activeTouches[id]
    if not touch or touch.initialX == nil then return end

    local nx, ny = normalizeCoords(x, y) 
    
    if touch.type == 'dpad' then
        local initialX = touch.initialX
        local initialY = touch.initialY
        local maxRadius = touch.maxRadius
        
        local diffX = nx - initialX
        local diffY = ny - initialY
        local distance = math.sqrt(diffX^2 + diffY^2)

        if distance > maxRadius then
            local scale = maxRadius / distance
            diffX = diffX * scale
            diffY = diffY * scale
            distance = maxRadius
        end
        
        touch.knobX = initialX + diffX
        touch.knobY = initialY + diffY
        
        local threshold = MOVE_THRESHOLD 
        game.player.moveLeft = false; game.player.moveRight = false
        game.player.moveUp = false; game.player.moveDown = false
        
        if distance > threshold then
            local normX = diffX / distance
            local normY = diffY / distance
            
            if normX < -DIRECTION_RATIO then game.player.moveLeft = true end
            if normX > DIRECTION_RATIO then game.player.moveRight = true end
            if normY < -DIRECTION_RATIO then game.player.moveUp = true end
            if normY > DIRECTION_RATIO then game.player.moveDown = true end
        end

    elseif touch.type == 'camera' then
        if game.player and game.player.rotate then
            local sensitivity = touch.sensitivity or CAMERA_SENSITIVITY
            
            local screenW = love.graphics.getWidth()
            local adjustedDx = dx 
            
            if love.touch and love.touch.getPosition(id) and love.touch.getPosition(id) <= 1 then 
                 adjustedDx = dx * screenW
            end

            game.player:rotate(adjustedDx * sensitivity)
        end
    end
end

function M.touchreleased(id, x, y, pressure, game)
    game = ensureGame(game)
    if not game then return end

    if game.state ~= "playing" then return end

    if game.inventory.isOpen then
        game.inventory:touchreleased(id, x, y, pressure)
        activeTouches[id] = nil
        return
    end
    
    local touch = activeTouches[id]
    if not touch then return end
    
    if touch.type == "dpad" then
        game.player.moveLeft = false; game.player.moveRight = false
        game.player.moveUp = false; game.player.moveDown = false
    end
    
    activeTouches[id] = nil
end

M.draw = touchControls.draw

return M