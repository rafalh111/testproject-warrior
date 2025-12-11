local M = {}
local love = love or {}

-- ============================================================
-- KONFIGURACJA PRZYCISKÓW HUD (zmienne nazwane są krócej)
-- ============================================================
local ICON_SIZE = 32 
local PADDING = 10 
local Y_OFFSET = 80

local START_X_RATIO = 0.0 
local START_Y_RATIO = 0.0 

local UI_SCALE = 1.0 
local DYNAMIC_SCALE = false -- Usunięto, bo w Twoim kodzie było false

-- ============================================================
-- ZMIENNE WEWNĘTRZNE I INICJALIZACJA
-- ============================================================
local optionsIcon = nil
local inventoryIcon = nil
local hudElements = {} 
local isMobile = false


function M.load()
    optionsIcon = love.graphics.newImage("sprites/optionsicon.png")
    inventoryIcon = love.graphics.newImage("sprites/inventoryicon.png")

    local osname = love.system and love.system.getOS() or "Unknown"
    isMobile = (osname == "Android" or osname == "iOS")
end

-- ============================================================
-- FUNKCJE POMOCNICZE
-- ============================================================

local function normalizeCoords(x, y)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    if x >= 0 and x <= 1 and y >= 0 and y <= 1 and isMobile then
        return x * screenW, y * screenH
    end
    return x, y
end


-- Generuje pozycje przycisków
local function generateHudElements(w, h)
    local tempHudElements = {}
    
    -- Usunięcie DYNAMIC_SCALE i uproszczenie skalowania
    local currentScale = UI_SCALE
    local s_iconSize = ICON_SIZE * currentScale
    local s_padding = PADDING * currentScale
    local s_yOffset = Y_OFFSET * currentScale

    local startX = w * START_X_RATIO
    local startY = h * START_Y_RATIO
    
    -- Wyrównanie do krawędzi
    if START_X_RATIO < 0.5 then startX = startX + s_padding
    else startX = startX - s_iconSize - s_padding end
    
    if START_Y_RATIO < 0.5 then startY = startY + s_yOffset
    else startY = startY - s_iconSize - s_yOffset end


    local currentX = startX
    local commonY = startY

    -- 1. PRZYCISK OPCJE
    table.insert(tempHudElements, {
        name = "options", x = currentX, y = commonY, w = s_iconSize, h = s_iconSize, action = "open_menu",
        icon = optionsIcon -- Dodano referencję do ikony
    })
    currentX = currentX + s_iconSize + s_padding


    -- 2. PRZYCISK INVENTORY
    table.insert(tempHudElements, {
        name = "inventory", x = currentX, y = commonY, w = s_iconSize, h = s_iconSize, action = "toggle_inventory",
        icon = inventoryIcon -- Dodano referencję do ikony
    })
    
    hudElements = tempHudElements
    return tempHudElements, currentScale
end

-- Sprawdza trafienie
function M.checkHit(x, y)
    local nx, ny = normalizeCoords(x, y) 

    if type(nx) ~= 'number' or type(ny) ~= 'number' then return nil end

    for _, btn in ipairs(hudElements) do 
        if nx >= btn.x and nx <= btn.x + btn.w and
           ny >= btn.y and ny <= btn.y + btn.h then
            return btn
        end
    end

    return nil
end

-- ============================================================
-- GŁÓWNE FUNKCJE LOVE2D (Rysowanie i Obsługa)
-- ============================================================

function M.draw(game)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local currentHud, currentScale = generateHudElements(w, h)

    -- Optymalizacja: Używamy M.checkHit tylko dla PC/myszy, dotyk jest już obsługiwany w touchpressed
    local mx, my = love.mouse.getPosition() 
    local hitBtn = M.checkHit(mx, my)

    love.graphics.setColor(1, 1, 1)

    for _, btn in ipairs(currentHud) do
        local icon = btn.icon 
        
        if icon then
            love.graphics.draw(icon, btn.x, btn.y, 0, btn.w / icon:getWidth(), btn.h / icon:getHeight())
        end

        -- Hover/Aktywny stan
        if hitBtn == btn then
            love.graphics.setColor(1, 1, 0)
            love.graphics.setLineWidth(math.max(1, 2 * currentScale))
            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1)
        end
    end

    -- DEBUG (uproszczony)
    if game and game.debugMode then
        love.graphics.setColor(1, 0, 0, 0.5)
        for _, btn in ipairs(hudElements) do 
            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        end
        love.graphics.setColor(1, 1, 1)
    end
end


-- Obsługa kliknięcia (mysz i dotyk używają tej samej logiki akcji)
function M.mousepressed(x, y, button, game)
    if type(game) ~= "table" then return false end
    
    local hit = M.checkHit(x, y) 

    if hit then
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

-- Obsługa DOTYKU (przekierowanie do M.mousepressed)
function M.touchpressed(id, x, y, pressure, game)
    return M.mousepressed(x, y, 1, game) 
end


return M