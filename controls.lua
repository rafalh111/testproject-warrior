-- controls.lua (Scalony, finalny)
-- Zawiera HUD (options/inventory), mobilny D-Pad i ActionB, mapowanie klawiszy, obsługę myszy i dotyku.
local M = {}
local math = math or {}
local love = love or {}

-- ============================================================
-- KONFIGURACJA
-- ============================================================
local DPAD_AREA_SIZE = 180
local ACTION_BUTTON_SIZE = 90
local KNOB_RADIUS_RATIO = 3.5
local MOVE_THRESHOLD = 20
local DIRECTION_RATIO = 0.3
local CAMERA_SENSITIVITY = 0.5

local PADDING = 20
local UI_SCALE = 1.0
local ICON_SIZE = 32
local HUD_Y_OFFSET = 80
local HUD_START_X_RATIO = 0.0
local HUD_START_Y_RATIO = 0.0

-- Czas minimalny, jaki musi upłynąć między otwarciem/zamknięciem Inventory (0.5 sekundy)
local INVENTORY_TOGGLE_COOLDOWN = 0.5 

-- ============================================================
-- STAN WEWNĘTRZNY
-- ============================================================
local menuRef = nil
local activeTouches = {}      -- map id -> touch info
local controlsDefined = false
local touchControls = {}      -- will hold button definitions and draw/check funcs
local isMobile = false
local lastInventoryToggleTime = 0 -- ZMIANA 1: Nowa zmienna do śledzenia czasu

-- HUD images (safe load)
local optionsIcon = nil
local inventoryIcon = nil

-- ============================================================
-- POMOCNICZE
-- ============================================================
local function ensureGame(game)
    game = game or _G.Game or _G.game
    if not game then
        print("[ERROR] controls.lua: game == nil")
        return nil
    end
    return game
end

local function normalizeCoords(x, y)
    -- On mobile love.* touch coords can be 0..1, convert to pixels
    if not love or not love.graphics then return x, y end
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local osname = love.system and love.system.getOS() or "Unknown"
    local isMobileOS = (osname == "Android" or osname == "iOS")
    if type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 and isMobileOS then
        return x * screenW, y * screenH
    end
    return x, y
end

local function safeNewImage(path)
    if not love or not love.graphics or not love.graphics.newImage then return nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok then return img end
    return nil
end

-- ============================================================
-- DEFINICJA PRZYCISKÓW (HUD + MOBILNE)
-- ============================================================

function touchControls.defineButtons(w, h)
    local buttons = {}

    -- HUD icons position (always visible)
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

    -- Options icon
    table.insert(buttons, {
        name = "options", type = "icon_btn",
        x = currentX, y = commonY, w = s_iconSize, h = s_iconSize,
        action = "open_menu"
    })
    currentX = currentX + s_iconSize + s_padding

    -- Inventory icon
    table.insert(buttons, {
        name = "inventory", type = "icon_btn",
        x = currentX, y = commonY, w = s_iconSize, h = s_iconSize,
        action = "toggle_inventory"
    })

    -- Mobile controls only when isMobile == true
    if isMobile then
        local buttonSize = ACTION_BUTTON_SIZE * UI_SCALE
        local dpadAreaSize = DPAD_AREA_SIZE * UI_SCALE
        local padding = PADDING * UI_SCALE

        -- Dpad area: left bottom
        table.insert(buttons, {
            name = "DpadArea", type = "dpad",
            x = padding, y = h - dpadAreaSize - padding,
            w = dpadAreaSize, h = dpadAreaSize, action = "move"
        })

        -- Action button: right bottom
        table.insert(buttons, {
            name = "ActionB", type = "action_btn",
            x = w - buttonSize - padding, y = h - buttonSize - padding,
            w = buttonSize, h = buttonSize, action = "reload"
        })
    end

    touchControls.buttons = buttons
    touchControls.currentScale = UI_SCALE
    controlsDefined = true
end

function touchControls.checkButton(x, y)
    if not controlsDefined or not touchControls.buttons then return nil end
    local nx, ny = x, y
    for _, btn in ipairs(touchControls.buttons) do
        if nx >= btn.x and nx <= btn.x + btn.w and ny >= btn.y and ny <= btn.y + btn.h then
            return btn
        end
    end
    return nil
end

-- ============================================================
-- RYSOWANIE (HUD + MOBILNE)
-- ============================================================
function touchControls.draw(game)
    if not controlsDefined then return end

    love.graphics.push()
    love.graphics.origin()

    local mx, my = love.mouse.getPosition()
    local nmx, nmy = normalizeCoords(mx, my)
    local hitBtn = touchControls.checkButton(nmx, nmy)

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
            -- draw icon
            local icon = (button.name == "options" and optionsIcon) or (button.name == "inventory" and inventoryIcon)
            love.graphics.setColor(1, 1, 1, 1)
            if icon and icon.getWidth then
                love.graphics.draw(icon, button.x, button.y, 0, button.w / icon:getWidth(), button.h / icon:getHeight())
            else
                -- fallback: simple rectangle with letter
                love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
                love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 4, 4)
                love.graphics.setColor(1, 1, 1, 1)
                local label = (button.name == "options" and "O") or (button.name == "inventory" and "I")
                love.graphics.printf(label, button.x, button.y + button.h/2 - 8, button.w, "center")
            end

            -- ZMIENIONO: Dodanie żółtej ramki na dotyk
            if isPressed then
                love.graphics.setColor(1, 1, 0, 1) -- Żółty
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 4, 4)
                love.graphics.setLineWidth(1) -- Reset linii
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

    -- debug outlines
    if game and game.debugMode then
        love.graphics.setColor(1, 0, 0, 0.5)
        for _, btn in ipairs(touchControls.buttons or {}) do
            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        end
        love.graphics.setColor(1,1,1,1)
    end
end

-- ============================================================
-- HUD ACTION HANDLER
-- ============================================================
local function handleHudAction(hit, game)
    if not hit or not game then return false end

    if hit.type == "icon_btn" then
        if hit.action == "toggle_inventory" then
            local currentTime = love.timer.getTime()
            
            -- ZMIANA 2: Sprawdzenie cooldownu
            if currentTime - lastInventoryToggleTime < INVENTORY_TOGGLE_COOLDOWN then
                return false -- Akcja zablokowana przez cooldown
            end

            if game.inventory and game.inventory.toggle then
                game.inventory:toggle()
                
                -- ZMIANA 2: Aktualizacja czasu ostatniego przełączenia
                lastInventoryToggleTime = currentTime
                
                -- Dodano symulowane zwolnienie myszy/akcji, aby zresetować stan gracza po akcji HUD/Menu.
                if game.player and game.player.mousereleased then
                    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
                    game.player:mousereleased(w/2, h/2, 1)
                end
                
                return true
            end
        elseif hit.action == "open_menu" then
            game.state = "menu"
            return true
        end
    end

    if isMobile and hit.type == "action_btn" then
        -- Action button służy TYLKO do przeładowania
        if game.player and game.player.keypressed then
            game.player:keypressed('r')
            return true
        end
    end

    return false
end

-- ============================================================
-- LOAD / INIT / REFRESH
-- ============================================================
function M.load()
    local osname = love.system and love.system.getOS() or "Unknown"
    isMobile = (osname == "Android" or osname == "iOS")

    -- Try to load icons safely
    optionsIcon = optionsIcon or safeNewImage("sprites/optionsicon.png") or safeNewImage("textures/ui/options.png")
    inventoryIcon = inventoryIcon or safeNewImage("sprites/inventoryicon.png") or safeNewImage("textures/ui/inventory.png")
end

function M.init(menu)
    menuRef = menu
    M.load()
    M.refreshControls()
end

function M.refreshControls()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    touchControls.defineButtons(w, h)
end

-- ============================================================
-- MAPKEY / GETBOUNDKEY
-- ============================================================
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

-- ============================================================
-- TEXT / KEYBOARD
-- ============================================================
function M.textinput(t, game)
    game = ensureGame(game)
    if not game or not game.menu or not game.menu.textinput then return end
    game.menu:textinput(t, game)
end

function M.keypressed(key, game)
    game = ensureGame(game)
    if not game then return end

    if key == "f3" then
        game.debugMode = not game.debugMode
        return
    end

    if game.state == "menu" or game.state == "nick_input" then
        if game.menu and game.menu.keypressed then
            local action = game.menu:keypressed(key, game)
            if game.state == "menu" or game.state == "nick_input" then
                if action == "start" and game.menu.nameEntered then
                    game.state = "playing"
                    if game.menu.playerNameInput then game.player.name = game.menu.playerNameInput end
                elseif action == "quit" then
                    love.event.quit()
                end
            end
        end
        return
    end

    if game.state == "playing" then
        if game.leveling and game.leveling.levelUpAvailable then
            if game.leveling.keypressed then game.leveling:keypressed(key) end
            return
        end

        local mappedKey = M.MapKey(key)

        -- ZMIANA 3: Sprawdzenie cooldownu dla klawiszy 'E'/'Inventory'
        if mappedKey == "inventory" or key == "e" then
            local currentTime = love.timer.getTime()
            if currentTime - lastInventoryToggleTime < INVENTORY_TOGGLE_COOLDOWN then
                return -- Zablokowanie przełączenia klawiszem
            end
            
            if game.inventory and game.inventory.isOpen then
                if game.inventory.toggle then 
                    game.inventory:toggle()
                    lastInventoryToggleTime = currentTime -- Aktualizacja czasu
                end
            else 
                if game.inventory and game.inventory.toggle then 
                    game.inventory:toggle()
                    lastInventoryToggleTime = currentTime -- Aktualizacja czasu
                end
            end
            
            -- Jeśli Inwentarz jest otwarty, nadal pozwalamy na obsługę klawiszy w nim
            if game.inventory and game.inventory.isOpen and game.inventory.keypressed then 
                 game.inventory:keypressed(key)
            end
            
            return
        end

        -- ... (reszta logiki klawiszy)
        if game.inventory and game.inventory.isOpen then
            if game.inventory.keypressed then game.inventory:keypressed(key) end
            return
        end


        if key == "1" and game.quickslots then game.quickslots.currentSlot = 1; game.quickslots:useCurrentSlot(); return end
        if key == "2" and game.quickslots then game.quickslots.currentSlot = 2; game.quickslots:useCurrentSlot(); return end
        if key == "3" and game.quickslots then game.quickslots.currentSlot = 3; game.quickslots:useCurrentSlot(); return end

        if game.player and game.player.keypressed then game.player:keypressed(key) end

        -- Oryginalna logika inventory usunięta, przeniesiona wyżej
        
        if key == "escape" then
            game.state = "menu"
        end

        if key == "return" and game.arcade and game.arcade.interact and game.arcade:interact(game.player) then
            if game.snake and game.snake.load then
                game.snake:load()
                game.state = "snake"
            end
        end
        return
    end

    if game.state == "snake" and game.snake and game.snake.keypressed then
        game.snake:keypressed(key)
        if key == "escape" then game.state = "playing" end
    end
end

-- ============================================================
-- MOUSE (desktop) / DRAG & DROP
-- ============================================================
function M.mousepressed(x, y, button, game)
    game = ensureGame(game)
    if not game then return end

    local nx, ny = normalizeCoords(x, y)

    -- Leveling popup
    if game.leveling and game.leveling.levelUpAvailable and game.leveling.mousepressed then
        if game.leveling:mousepressed(nx, ny, button) then return end
    end

    -- If menu (menu.lua teraz tylko rejestruje 'pressed', nie wykonuje akcji)
    if game.state == "menu" or game.state == "nick_input" then
        if game.menu and game.menu.mousepressed then
            game.menu:mousepressed(nx, ny, button, game)
            return
        end
    end

    -- HUD buttons check first for desktop (we want clicks on icons to be immediate)
    local hit = touchControls.checkButton(nx, ny)
    if hit and hit.type == "icon_btn" then
        -- Akcja jest sprawdzana przez cooldown w handleHudAction
        if handleHudAction(hit, game) then return end 
    end

    -- Inventory drag/drop uses raw coords
    if game.state == "playing" and game.inventory and game.inventory.isOpen and game.inventory.mousepressed then
        game.inventory:mousepressed(x, y, button)
        return
    end

    if game.state == "playing" then
        if hit and hit.type == "action_btn" then
            -- action button pressed (desktop click on ActionB)
            if handleHudAction(hit, game) then return end
        end

        -- pass to player
        if game.player and game.player.mousepressed then
            game.player:mousepressed(nx, ny, button)
        end
    end
end

-- POPRAWIONA FUNKCJA MOUSERELEASED
function M.mousereleased(x, y, button, game)
    game = ensureGame(game)
    if not game then return end

    -- ZMIANA 4: PRIORYTET DLA OBSŁUGI MENU
    if game.state == "menu" or game.state == "nick_input" then
        if game.menu and game.menu.mousereleased then
            -- Przekazujemy zdarzenie do menu, które sprawdzi logikę 'tapnięcia' (krótki klik)
            game.menu:mousereleased(x, y, button, game)
            return -- Zawsze wychodzimy, jeśli obsłużyliśmy menu
        end
    end

    -- Stara logika Inventory/In-Game (dotyczy tylko stanu "playing")
    if game.state == "playing" and game.inventory and game.inventory.isOpen and game.inventory.mousereleased then
        game.inventory:mousereleased(x, y, button)
        return
    end

    -- Dodatkowe czyszczenie stanu naciśnięcia gracza w grze (jeśli to było kliknięcie ataku/akcji)
    if game.state == "playing" and game.player and game.player.mousereleased then
         game.player:mousereleased(x, y, button)
    end
end

function M.wheelmoved(x, y, game)
    game = ensureGame(game)
    if not game then return end

    if game.state == "playing" and not (game.inventory and game.inventory.isOpen) and game.quickslots then
        local delta = (y > 0 and -1) or (y < 0 and 1) or 0
        if delta ~= 0 then game.quickslots:changeSlot(delta) end
    end
end

-- ============================================================
-- TOUCH (mobile) - PRIORYTETY: DPAD -> ACTIONB -> HUD -> CAMERA
-- ============================================================
function M.touchpressed(id, x, y, pressure, game)
    game = ensureGame(game)
    if not game then return end

    if not controlsDefined then M.refreshControls() end
    local nx, ny = normalizeCoords(x, y)

    -- menu handling
    if game.state == "menu" or game.state == "nick_input" then
        if game.menu and game.menu.mousepressed then
            game.menu:mousepressed(nx, ny, 1, game)
        end
        return
    end

    -- Leveling popup priority
    if game.leveling and game.leveling.levelUpAvailable and game.leveling.mousepressed then
        if game.leveling:mousepressed(nx, ny, 1) then
            activeTouches[id] = { id = id, type = 'leveling' }
            return
        end
    end

    if game.state ~= "playing" then return end

    local button = touchControls.checkButton(nx, ny)

    -- 1) Check D-Pad area first
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

    -- 2) Check ActionB (reload)
    if button and button.type == "action_btn" then
        activeTouches[id] = { id = id, type = 'button', name = button.name, pressedTime = love.timer.getTime() } 
        
        -- Action button służy TYLKO do przeładowania (wykonywane natychmiast, ale nadal rejestrowane jako "button")
        if game.player and game.player.keypressed then
            game.player:keypressed('r')
        end
        return
    end

    -- 3) ZMIENIONO: Check HUD icons (Options/Inventory)
    if button and (button.type == "icon_btn") then
        -- Akcja przeniesiona na touchreleased, ale rejestrujemy dotyk i czas
        activeTouches[id] = { 
            id = id, 
            type = 'button', 
            name = button.name,
            pressedTime = love.timer.getTime() -- Rejestracja czasu naciśnięcia
        }
        return
    end

    -- 4) Camera touch (look/shot) - PRZESUNIĘTE NA KONIEC
    if not button then
        activeTouches[id] = { id = id, type = 'camera', initialX = nx, initialY = ny, sensitivity = CAMERA_SENSITIVITY }
        if game.player and game.player.mousepressed then game.player:mousepressed(nx, ny, 1) end
        return
    end
end

function M.touchmoved(id, x, y, dx, dy, pressure, game)
    game = ensureGame(game)
    if not game then return end
    if game.state ~= "playing" then return end

    local touch = activeTouches[id]
    if not touch then return end
    if touch.type == 'leveling' then return end

    -- POPRAWKA: Jeśli dotyk zaczął się na ikonie (touch.type == 'button'),
    -- nie pozwalamy Inventory na przechwycenie go jako przeciąganie/ruch.
    if game.inventory and game.inventory.isOpen and game.inventory.touchmoved and touch.type ~= 'button' then
        game.inventory:touchmoved(id, x, y, pressure)
        return
    end

    local nx, ny = normalizeCoords(x, y)

    if touch.type == 'dpad' then
        local centerX = touch.centerX or touch.initialX
        local centerY = touch.centerY or touch.initialY
        local maxRadius = touch.maxRadius or (DPAD_AREA_SIZE * UI_SCALE / 2)

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

        -- Update player directional flags
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
            local sensitivity = touch.sensitivity or CAMERA_SENSITIVITY
            local adjustedDx = dx
            if math.abs(dx) <= 1 then adjustedDx = dx * love.graphics.getWidth() end
            game.player:rotate(adjustedDx * sensitivity)
        end
    end
end

function M.touchreleased(id, x, y, pressure, game)
    game = ensureGame(game)
    if not game then return end
    if game.state ~= "playing" then activeTouches[id] = nil; return end

    local touch = activeTouches[id]
    if not touch then return end

    if touch.type == 'leveling' then
        activeTouches[id] = nil
        return
    end
    
    -- ZMIENIONO: Logika obsługi przycisku HUD (icon_btn)
    if touch.type == 'button' then
        local releaseTime = love.timer.getTime()
        local pressDuration = releaseTime - (touch.pressedTime or 0)
        local isTap = pressDuration < 0.3 -- Definiujemy tapnięcie jako krótsze niż 300ms
        
        -- Wywołaj akcję tylko, jeśli było to szybkie tapnięcie na ikonie
        if isTap and (touch.name == "inventory" or touch.name == "options") then
            local nx, ny = normalizeCoords(x, y)
            local hit = touchControls.checkButton(nx, ny)
            -- Sprawdź, czy palec zwolniono w obrębie przycisku
            if hit and hit.name == touch.name then 
                handleHudAction(hit, game) -- Akcja sprawdzi cooldown
            end
        end

        activeTouches[id] = nil
        return
    end

    -- Stara logika Inventory drag/drop: działa tylko dla dotyków, które nie były przyciskiem.
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
-- ============================================================
-- APPLY DPAD MOVEMENT (per-frame)
-- ============================================================
local function applyDpadMovement(game)
    if not game then return end
    local moveX, moveY = 0, 0
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

-- ============================================================
-- UPDATE / DRAW PROXY
-- ============================================================
function M.update(dt, game)
    game = ensureGame(game)
    if not game then return end

    if not controlsDefined then touchControls.defineButtons(love.graphics.getWidth(), love.graphics.getHeight()) end

    applyDpadMovement(game)
end

function M.draw(game)
    touchControls.draw(game)
end

-- ============================================================
-- MOUSE convenience forward (desktop)
-- ============================================================
function M.mousemoved(x, y, dx, dy)
    if activeTouches["mouse"] and activeTouches["mouse"].type == "camera" then
        M.touchmoved("mouse", x, y, dx, dy, 0, _G.Game)
    end
end

-- ============================================================
-- LOAD ASSETS PUBLIC
-- ============================================================
function M.loadAssets()
    optionsIcon = optionsIcon or safeNewImage("textures/ui/options.png") or safeNewImage("sprites/optionsicon.png")
    inventoryIcon = inventoryIcon or safeNewImage("textures/ui/inventory.png") or safeNewImage("sprites/inventoryicon.png")
end

-- ============================================================
-- EXPORT
-- ============================================================
M.draw = M.draw
M.update = M.update
M.touchpressed = M.touchpressed
M.touchmoved = M.touchmoved
M.touchreleased = M.touchreleased
M.mousepressed = M.mousepressed
M.mousereleased = M.mousereleased
M.mousemoved = M.mousemoved
M.keypressed = M.keypressed
M.textinput = M.textinput
M.wheelmoved = M.wheelmoved
M.load = M.load
M.init = M.init
M.refreshControls = M.refreshControls
M.MapKey = M.MapKey
M.GetBoundKey = M.GetBoundKey
M.loadAssets = M.loadAssets

return M