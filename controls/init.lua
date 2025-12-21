-- controls/init.lua
local M = {}
local math = math or {}
local love = love or {}

-- ============================================================
-- KONFIGURACJA (Współdzielona / PC)
-- ============================================================
local INVENTORY_TOGGLE_COOLDOWN = 0.5
local CAMERA_SENSITIVITY = 0.5
local PADDING = 10
local UI_SCALE = 1.0
local ICON_SIZE = 32
local HUD_Y_OFFSET = 80
local HUD_START_X_RATIO = 0.0
local HUD_START_Y_RATIO = 0.0

-- ============================================================
-- STAN WEWNĘTRZNY (Współdzielony)
-- ============================================================
local menuRef = nil
local activeTouches = {}
local controlsDefined = false
local touchControls = {}
local isMobile = false
local lastInventoryToggleTime = 0

-- HUD images
local optionsIcon = nil
local inventoryIcon = nil
local statsIcon = nil

-- Moduł dotykowy
local TouchModule = require((...):gsub('%.init$', '') .. ".touch")

-- ============================================================
-- POMOCNICZE
-- ============================================================
local function ensureGame(game)
    game = game or _G.Game or _G.game
    if not game then return nil end
    return game
end

local function normalizeCoords(x, y)
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
-- HUD ACTION HANDLER (Współdzielony logicznie)
-- ============================================================
local function handleHudAction(hit, game)
    if not hit or not game then return false end

    if hit.type == "icon_btn" then
        if hit.action == "toggle_inventory" then
            local currentTime = love.timer.getTime()
            if currentTime - lastInventoryToggleTime < INVENTORY_TOGGLE_COOLDOWN then return false end

            if game.inventory and game.inventory.toggle then
                game.inventory:toggle()
                lastInventoryToggleTime = currentTime
                
                -- Reset myszy gracza
                if game.player and game.player.mousereleased then
                    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
                    game.player:mousereleased(w/2, h/2, 1)
                end
                return true
            end
            
        elseif hit.action == "toggle_stats" then
             -- === NOWA AKCJA: OTWIERANIE STATYSTYK ===
             if game.leveling and game.leveling.toggle then
                 game.leveling:toggle()
                 return true
             end
            
        elseif hit.action == "open_menu" then
            game.state = "menu"
            return true
        end
    end

    if isMobile and hit.type == "action_btn" then
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
    statsIcon = statsIcon or safeNewImage("sprites/statsicon.png") or safeNewImage("textures/ui/stats.png")

    M.loadAssets = M.loadAssets -- self reference fix if called externally
end

function M.init(menu)
    menuRef = menu
    M.load()
    M.refreshControls()
end

function M.refreshControls()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    -- Przekazujemy kontekst do modułu dotykowego przy odświeżaniu, aby zaktualizował definicje
    local ctx = {
        touchControls = touchControls,
        isMobile = isMobile,
        ICON_SIZE = ICON_SIZE, UI_SCALE = UI_SCALE, PADDING = PADDING,
        HUD_Y_OFFSET = HUD_Y_OFFSET, HUD_START_X_RATIO = HUD_START_X_RATIO, HUD_START_Y_RATIO = HUD_START_Y_RATIO
    }
    TouchModule.defineButtons(w, h, ctx)
    controlsDefined = true
end

function M.loadAssets()
    optionsIcon = optionsIcon or safeNewImage("textures/ui/options.png") or safeNewImage("sprites/optionsicon.png")
    inventoryIcon = inventoryIcon or safeNewImage("textures/ui/inventory.png") or safeNewImage("sprites/inventoryicon.png")
    statsIcon = statsIcon or safeNewImage("textures/ui/stats.png") or safeNewImage("sprites/statsicon.png")
end

-- ============================================================
-- KONFIGURACJA MODUŁU DOTYKOWEGO (PRZEKAZYWANIE STANU)
-- ============================================================
-- Przygotowanie kontekstu dla funkcji dotykowych
local function getTouchContext()
    return {
        M = M,
        love = love,
        math = math,
        activeTouches = activeTouches,
        touchControls = touchControls,
        isMobile = isMobile,
        controlsDefined = controlsDefined,
        menuRef = menuRef,
        ensureGame = ensureGame,
        normalizeCoords = normalizeCoords,
        handleHudAction = handleHudAction,
        CAMERA_SENSITIVITY = CAMERA_SENSITIVITY,
        UI_SCALE = UI_SCALE,
        images = { options = optionsIcon, inventory = inventoryIcon, stats = statsIcon },
        refreshControls = M.refreshControls
    }
end

-- ============================================================
-- OBSŁUGA KOMPUTERA (KLAWIATURA, MYSZ)
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

function M.textinput(t, game)
    game = ensureGame(game)
    if not game or not game.menu or not game.menu.textinput then return end
    game.menu:textinput(t, game)
end

function M.keypressed(key, game)
    game = ensureGame(game)
    if not game then return end

    if key == "f3" then game.debugMode = not game.debugMode; return end

    if game.state == "menu" or game.state == "nick_input" then
        if game.menu and game.menu.keypressed then
            local action = game.menu:keypressed(key, game)
            if game.state == "menu" or game.state == "nick_input" then
                if action == "start" and game.menu.nameEntered then
                    game.state = "playing"
                    if game.menu.playerNameInput then game.player.name = game.menu.playerNameInput end
                elseif action == "quit" then love.event.quit() end
            end
        end
        return
    end

    if game.state == "playing" then
        -- Jeśli leveling jest OTWARTY (isOpen), to on przejmuje sterowanie
        if game.leveling and game.leveling.isOpen then
             if game.leveling.keypressed then game.leveling:keypressed(key) end
             return
        end

        local mappedKey = M.MapKey(key)

        if mappedKey == "inventory" or key == "e" then
            local currentTime = love.timer.getTime()
            if currentTime - lastInventoryToggleTime < INVENTORY_TOGGLE_COOLDOWN then return end
            
            if game.inventory and game.inventory.toggle then 
                game.inventory:toggle()
                lastInventoryToggleTime = currentTime 
            end
            
            if game.inventory and game.inventory.isOpen and game.inventory.keypressed then 
                 game.inventory:keypressed(key)
            end
            return
        end

        if game.inventory and game.inventory.isOpen then
            if game.inventory.keypressed then game.inventory:keypressed(key) end
            return
        end

        if key == "1" and game.quickslots then game.quickslots.currentSlot = 1; game.quickslots:useCurrentSlot(); return end
        if key == "2" and game.quickslots then game.quickslots.currentSlot = 2; game.quickslots:useCurrentSlot(); return end
        if key == "3" and game.quickslots then game.quickslots.currentSlot = 3; game.quickslots:useCurrentSlot(); return end

        if game.player and game.player.keypressed then game.player:keypressed(key) end
        
        if key == "escape" then game.state = "menu" end
        
        -- Klawisz skrótu do statystyk (np. P lub C)
        if key == "p" or key == "c" then
             if game.leveling and game.leveling.toggle then game.leveling:toggle() end
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

function M.mousepressed(x, y, button, game)
    game = ensureGame(game)
    if not game then return end

    local nx, ny = normalizeCoords(x, y)

    -- Jeśli leveling jest OTWARTY, sprawdź kliknięcie w nim
    if game.leveling and game.leveling.isOpen and game.leveling.mousepressed then
        if game.leveling:mousepressed(nx, ny, button) then return end
        -- Jeśli kliknięto poza oknem levelingu, można je zamknąć (opcjonalnie)
    end

    if game.state == "menu" or game.state == "nick_input" then
        if game.menu and game.menu.mousepressed then game.menu:mousepressed(nx, ny, button, game); return end
    end

    -- Użycie funkcji z modułu dotykowego do sprawdzania przycisków
    local hit = TouchModule.checkButton(nx, ny, touchControls)
    if hit and hit.type == "icon_btn" then
        if handleHudAction(hit, game) then return end 
    end

    if game.state == "playing" and game.inventory and game.inventory.isOpen and game.inventory.mousepressed then
        game.inventory:mousepressed(x, y, button)
        return
    end

    if game.state == "playing" then
        if hit and hit.type == "action_btn" then
            if handleHudAction(hit, game) then return end
        end
        if game.player and game.player.mousepressed then game.player:mousepressed(nx, ny, button) end
    end
end

function M.mousereleased(x, y, button, game)
    game = ensureGame(game)
    if not game then return end

    if game.state == "menu" or game.state == "nick_input" then
        if game.menu and game.menu.mousereleased then game.menu:mousereleased(x, y, button, game); return end
    end

    if game.state == "playing" and game.inventory and game.inventory.isOpen and game.inventory.mousereleased then
        game.inventory:mousereleased(x, y, button)
        return
    end

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

function M.mousemoved(x, y, dx, dy)
    if activeTouches["mouse"] and activeTouches["mouse"].type == "camera" then
        M.touchmoved("mouse", x, y, dx, dy, 0, _G.Game)
    end
end

-- ============================================================
-- DELEGACJA DO DOTYKU
-- ============================================================
function M.touchpressed(id, x, y, pressure, game)
    TouchModule.touchpressed(id, x, y, pressure, game, getTouchContext())
end

function M.touchmoved(id, x, y, dx, dy, pressure, game)
    TouchModule.touchmoved(id, x, y, dx, dy, pressure, game, getTouchContext())
end

function M.touchreleased(id, x, y, pressure, game)
    TouchModule.touchreleased(id, x, y, pressure, game, getTouchContext())
end

function M.update(dt, game)
    game = ensureGame(game)
    if not game then return end
    if not controlsDefined then M.refreshControls() end
    TouchModule.update(dt, game, getTouchContext())
end

function M.draw(game)
    -- Aktualizacja obrazków w kontekście przed rysowaniem (gdyby zostały załadowane później)
    local ctx = getTouchContext()
    ctx.images = { options = optionsIcon, inventory = inventoryIcon, stats = statsIcon }
    TouchModule.draw(game, ctx)
end

return M