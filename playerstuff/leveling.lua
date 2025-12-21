local Leveling = {}
local math = math or {}
local love = love or {}
local player = nil 

-- KONFIGURACJA GRY
local BASE_WINDOW_WIDTH = 400
local BASE_WINDOW_HEIGHT = 350
local BASE_SCREEN_W = 800

-- STAN POZIOMOWANIA
Leveling.currentLevel = 0
Leveling.currentXP = 0
Leveling.XPToNextLevel = 2 
Leveling.levelCap = 100
Leveling.levelUpAvailable = false 
Leveling.attributePoints = 0 
Leveling.selectedAttribute = 1 
Leveling.isOpen = false

-- Okno ulepszeń
Leveling.window = {
    width = BASE_WINDOW_WIDTH,
    height = BASE_WINDOW_HEIGHT,
    scale = 1.0
}

Leveling.attributes = {
    "HP", "STR", "MANA", "STAMINA", "SPEED"
}

-- Definicja wzmocnień
Leveling.upgradeStats = {
    HP = { baseKey = "baseMaxHp", value = 5, name = "Max HP (+5% Bazowej)" },
    STR = { baseKey = "baseDamage", value = 5, name = "Damage (+5% Bazowej)" },
    MANA = { baseKey = "baseMaxMana", value = 5, name = "Max Mana (+5% Bazowej)" },
    STAMINA = { baseKey = "baseMaxStamina", value = 5, name = "Max Stamina (+5% Bazowej)" },
    SPEED = { baseKey = "baseSpeed", value = 1, name = "Movement Speed (+1% Bazowej)" },
}

-- FUNKCJE POMOCNICZE
local function calculateXP(level)
    if level >= Leveling.levelCap then return math.huge end
    return 2 ^ level
end

function Leveling:recalculateStats(attributeKey)
    local upgrade = Leveling.upgradeStats[attributeKey]
    if not upgrade then return end
    
    local pointsKey = upgrade.baseKey .. "Points"
    local points = player[pointsKey] or 0
    local base = player[upgrade.baseKey]

    local newValue = base + (base * (points / 100)) 
    
    if attributeKey == "SPEED" then
        newValue = base + points
    end

    if attributeKey == "HP" then
        local diff = newValue - (player.maxHp or base) 
        player.maxHp = newValue
        player.hp = (player.hp or player.maxHp) + diff 
    elseif attributeKey == "MANA" then
        local diff = newValue - (player.maxMana or base) 
        player.maxMana = newValue
        player.mana = (player.mana or player.maxMana) + diff 
    elseif attributeKey == "STR" then
        player.damage = newValue
    elseif attributeKey == "STAMINA" then
        player.maxStamina = newValue
    elseif attributeKey == "SPEED" then
        player.speed = newValue
    end
end

function Leveling:init(playerRef)
    player = playerRef
    
    -- Inicjalizacja statystyk (bez zmian)
    player.baseMaxHp = player.baseMaxHp or 100
    player.baseMaxMana = player.baseMaxMana or 100
    player.baseSpeed = player.baseSpeed or 300
    player.baseDamage = player.baseDamage or 5 
    player.baseMaxStamina = player.baseMaxStamina or 100
    
    local function initPoints(baseKey)
        player[baseKey .. "Points"] = player[baseKey .. "Points"] or 0
    end
    initPoints("baseMaxHp"); initPoints("baseMaxMana"); initPoints("baseDamage")
    initPoints("baseMaxStamina"); initPoints("baseSpeed")

    player.maxHp = player.maxHp or player.baseMaxHp
    player.hp = player.hp or player.maxHp
    player.maxMana = player.maxMana or player.baseMaxMana
    player.mana = player.mana or player.baseMaxMana
    player.damage = player.damage or player.baseDamage
    player.speed = player.speed or player.baseSpeed
    player.maxStamina = player.maxStamina or player.baseMaxStamina
    
    player.currentLevel = player.currentLevel or 1
    Leveling.XPToNextLevel = calculateXP(player.currentLevel)
    player.currentXP = player.currentXP or 0
    
    -- NAPRAWA: Na starcie upewnij się, że gracz nie jest zablokowany
    player.isLevelingUp = false
    
    self:recalculateWindowScale()
end

function Leveling:recalculateWindowScale()
    local screenW = love.graphics.getWidth() or BASE_SCREEN_W
    local newScale = math.min(1.0, screenW / BASE_SCREEN_W)
    Leveling.window.scale = newScale
    Leveling.window.width = BASE_WINDOW_WIDTH * newScale
    Leveling.window.height = BASE_WINDOW_HEIGHT * newScale
end

-- === NAPRAWA: Funkcja Toggle ===
function Leveling:toggle()
    self.isOpen = not self.isOpen
    
    if player then
        if self.isOpen then
            -- Otwieramy okno -> zatrzymujemy gracza
            player.isLevelingUp = true 
            Leveling.selectedAttribute = 1
            
            -- Czyścimy inputy ruchu, żeby nie "płynął" po otwarciu
            player.moveLeft = false
            player.moveRight = false
            player.moveUp = false
            player.moveDown = false
        else
            -- Zamykamy okno -> ODBLOKOWUJEMY gracza
            player.isLevelingUp = false
        end
    end
end

-- Funkcja dodająca XP
function Leveling:addXP(enemyDef)
    if Leveling.currentLevel >= Leveling.levelCap then return end
    
    local xpMin = enemyDef.xpMin or 0
    local xpMax = enemyDef.xpMax or 0

    local xpGained = 0
    if love.math and love.math.random then
        xpGained = love.math.random(xpMin, xpMax)
    elseif math.random then
        xpGained = math.floor(math.random() * (xpMax - xpMin + 1)) + xpMin
    else
        xpGained = xpMin
    end
    
    Leveling.currentXP = Leveling.currentXP + xpGained
    
    while Leveling.currentXP >= Leveling.XPToNextLevel do
        Leveling.currentLevel = Leveling.currentLevel + 1
        Leveling.attributePoints = Leveling.attributePoints + 1
        Leveling.currentXP = Leveling.currentXP - Leveling.XPToNextLevel
        Leveling.XPToNextLevel = calculateXP(Leveling.currentLevel)
        
        Leveling.levelUpAvailable = true
        
        if player then 
            player.isLevelingUp = false 
        end
        self.isOpen = false
        
        if Leveling.currentLevel >= Leveling.levelCap then break end
    end
end

-- Aktualizuje statystyki gracza po awansie
function Leveling:applyUpgrade(attributeKey)
    if Leveling.attributePoints < 1 then return end
    
    local upgrade = Leveling.upgradeStats[attributeKey]
    if not upgrade then return end
    
    local pointsKey = upgrade.baseKey .. "Points"

    if player[pointsKey] ~= nil then
        player[pointsKey] = player[pointsKey] + upgrade.value
        Leveling:recalculateStats(attributeKey)

        Leveling.attributePoints = Leveling.attributePoints - 1
        
        if Leveling.attributePoints == 0 then
            Leveling.levelUpAvailable = false
        end
    end
end

-- Obsługa klawiatury
function Leveling:keypressed(key)
    if not Leveling.isOpen then return end 

    local mappedKey = _G.MapKey and _G.MapKey(key) or key
    local maxAttributes = #Leveling.attributes

    if mappedKey == "up" or key == "up" or mappedKey == "w" or key == "w" then
        Leveling.selectedAttribute = math.max(1, Leveling.selectedAttribute - 1)
    elseif mappedKey == "down" or key == "down" or mappedKey == "s" or key == "s" then
        Leveling.selectedAttribute = math.min(maxAttributes, Leveling.selectedAttribute + 1)
    elseif key == "return" or key == "space" or key == "kpenter" or key == "e" then 
        local attributeKey = Leveling.attributes[Leveling.selectedAttribute]
        Leveling:applyUpgrade(attributeKey)
    elseif key == "escape" then
        self:toggle()
    end
end

-- Obsługa myszy
function Leveling:mousepressed(x, y, button)
    if not Leveling.isOpen or button ~= 1 then return false end
    
    self:recalculateWindowScale() 

    local win = Leveling.window
    local scale = win.scale
    local padding = 20 * scale
    local buttonH = 30 * scale
    local margin = 10 * scale
    local sideMargin = 20 * scale

    local screenWidth = love.graphics.getWidth()
    local winX = (screenWidth / 2) - (win.width / 2) 
    local winY = 50 * scale
    
    
    if not (x >= winX and x <= winX + win.width and y >= winY and y <= winY + win.height) then
        self:toggle()
        return false
    end
    
    for i, attr in ipairs(Leveling.attributes) do
        local btnY = winY + padding + (i * (buttonH + margin)) 
        local btnX = winX + sideMargin
        local btnW = win.width - (sideMargin * 2)
        
        if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + buttonH then
            Leveling.selectedAttribute = i
            Leveling:applyUpgrade(attr)
            return true
        end
    end
    
    return true
end


-- RYSOWANIE
function Leveling:draw()
    self:recalculateWindowScale()
    self:drawXPBar()
    
    if not Leveling.isOpen then return end
    
    local win = Leveling.window
    local scale = win.scale
    local padding = 40 * scale
    local buttonH = 40 * scale
    local margin = 10 * scale
    local sideMargin = 20 * scale

    local screenWidth = love.graphics.getWidth()
    local winX = (screenWidth / 2) - (win.width / 2) 
    local winY = 50 * scale 
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, love.graphics.getHeight())
    
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", winX, winY, win.width, win.height, 10 * scale) 
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.rectangle("line", winX, winY, win.width, win.height, 10 * scale) 
    
    love.graphics.setColor(1, 1, 1)
    local title = "STATS (" .. Leveling.attributePoints .. " points)"
    love.graphics.push()
    love.graphics.scale(scale, scale)
    love.graphics.printf(title, winX/scale, (winY + 10)/scale, win.width/scale, "center") 
    love.graphics.pop()
    
    for i, attr in ipairs(Leveling.attributes) do
        local upgrade = Leveling.upgradeStats[attr]
        local btnY = winY + padding + (i * (buttonH + margin)) 
        local btnX = winX + sideMargin 
        local btnW = win.width - (sideMargin * 2)
        
        if i == Leveling.selectedAttribute then
            love.graphics.setColor(0.9, 0.5, 0.1, 1)
            love.graphics.setLineWidth(3 * scale)
            love.graphics.rectangle("line", btnX - (5 * scale), btnY - (5 * scale), btnW + (10 * scale), buttonH + (10 * scale), 5 * scale)
            love.graphics.setLineWidth(1)
        end
        
        love.graphics.setColor(0.3, 0.3, 0.5)
        love.graphics.rectangle("fill", btnX, btnY, btnW, buttonH, 5 * scale)
        love.graphics.setColor(0.8, 0.8, 1)
        love.graphics.rectangle("line", btnX, btnY, btnW, buttonH, 5 * scale)
        
        love.graphics.push()
        love.graphics.scale(scale, scale)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(upgrade.name, btnX/scale, (btnY + 5)/scale, btnW/scale, "center")
        
        local currentVal = 0
        if attr == "HP" then currentVal = player.maxHp
        elseif attr == "STR" then currentVal = player.damage
        elseif attr == "MANA" then currentVal = player.maxMana
        elseif attr == "STAMINA" then currentVal = player.maxStamina
        elseif attr == "SPEED" then currentVal = player.speed end
        
        love.graphics.printf("Current: " .. math.floor(currentVal), btnX/scale, (btnY + 25)/scale, btnW/scale, "center")
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1)
end

function Leveling:drawXPBar()
    local uiScale = 1.0 
    local barWidth = 200 * uiScale
    local barHeight = 15 * uiScale
    local uiX = 10 * uiScale
    local uiY = (60) * uiScale 
    
    local xpPercent = math.max(0, math.min(Leveling.currentXP / Leveling.XPToNextLevel, 1))

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", uiX, uiY, barWidth, barHeight, 3, 3)
    love.graphics.setColor(0.2, 0.8, 0.4)
    love.graphics.rectangle("fill", uiX, uiY, xpPercent * barWidth, barHeight, 3, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", uiX, uiY, barWidth, barHeight, 3, 3)
    
    local xpText = string.format("Level %d | XP: %d / %d", 
                                 Leveling.currentLevel, 
                                 math.floor(Leveling.currentXP), 
                                 math.floor(Leveling.XPToNextLevel))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(xpText, uiX, uiY + barHeight/2 - 6, barWidth, "center")
end

return Leveling