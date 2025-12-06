local Leveling = {}
local player = nil -- Przekazana referencja do obiektu gracza
local ENEMY_XP_VALUE = 2 -- Slime daje 2 XP (dwa kille na pierwszy level)

-- -- -- STAN POZIOMOWANIA -- -- --
Leveling.currentLevel = 1
Leveling.currentXP = 0
Leveling.XPToNextLevel = 2 -- XP wymagane na level 2 (2^1 = 2)
Leveling.levelCap = 100
Leveling.levelUpAvailable = false -- Flaga, która aktywuje okno ulepszeń
Leveling.attributePoints = 0 -- Punkty do wydania
Leveling.selectedAttribute = 1 -- Zmienna do nawigacji klawiaturą

-- -- -- Okno ulepszeń -- -- --
Leveling.window = {
    width = 500, -- Zgodnie z Twoją prośbą
    height = 500 -- Zgodnie z Twoją prośbą
}

Leveling.attributes = {
    "HP",
    "STR",
    "MANA",
    "STAMINA",
    "SPEED"
}

-- Definicja wzmocnień na 1 punkt (wartość 1 = +1% do bazowej statystyki)
Leveling.upgradeStats = {
    HP = { baseKey = "baseMaxHp", value = 5, name = "Max HP (+5% Bazowej)" },
    STR = { baseKey = "baseDamage", value = 5, name = "Damage (+5% Bazowej)" },
    MANA = { baseKey = "baseMaxMana", value = 5, name = "Max Mana (+5% Bazowej)" },
    STAMINA = { baseKey = "baseMaxStamina", value = 5, name = "Max Stamina (+5% Bazowej)" },
    SPEED = { baseKey = "baseSpeed", value = 5, name = "Movement Speed (+5% Bazowej)" },
}


-- -- -- FUNKCJE POMOCNICZE -- -- --

-- Oblicza XP potrzebne na następny poziom
local function calculateXP(level)
    if level >= Leveling.levelCap then return math.huge end
    -- Binarna progresja: 2^(Level)
    return 2 ^ level
end

-- Aktualizuje statystyki gracza (poziomy % i płaskie) po wydaniu punktu.
-- Natychmiastowo uzupełnia HP/Mana, jeśli wzrasta.
function Leveling:recalculateStats(attributeKey)
    local upgrade = Leveling.upgradeStats[attributeKey]
    if not upgrade then return end
    
    local baseKey = upgrade.baseKey
    local pointsKey = baseKey .. "Points"
    local points = player[pointsKey] or 0

    if attributeKey == "HP" then
        local base = player.baseMaxHp
        local newMaxHp = base * (1 + (points / 100))
        local diff = newMaxHp - (player.maxHp or base) 
        
        player.maxHp = newMaxHp
        player.hp = (player.hp or player.maxHp) + diff -- Uzupełnienie obecnego HP
        
    elseif attributeKey == "MANA" then
        local base = player.baseMaxMana
        local newMaxMana = base * (1 + (points / 100))
        local diff = newMaxMana - (player.maxMana or base) 
        
        player.maxMana = newMaxMana
        player.mana = (player.mana or player.maxMana) + diff -- Uzupełnienie obecnej Many

    elseif attributeKey == "STR" then
        local base = player.baseDamage
        player.damage = base * (1 + (points / 100))
        
    elseif attributeKey == "STAMINA" then
        local base = player.baseMaxStamina
        player.maxStamina = base * (1 + (points / 100))
        
    elseif attributeKey == "SPEED" then
        local base = player.baseSpeed
        player.speed = base * (1 + (points / 100))
    end
end


-- Wymaga, aby player został przekazany z main.lua
function Leveling:init(playerRef)
    player = playerRef
    -- Jeśli obiekt gracza ma już zdefiniowane pola bazowe, używamy ich
    player.baseMaxHp = player.baseMaxHp or 100
    player.baseMaxMana = player.baseMaxMana or 100
    player.baseSpeed = player.baseSpeed or 300
    player.baseDamage = player.baseDamage or 5 -- Zakładając, że player.damage jest oparte na baseDamage
    player.baseMaxStamina = player.baseMaxStamina or 100
    
    -- Inicjalizacja pól do śledzenia punktów atrybutów
    player.baseMaxHpPoints = player.baseMaxHpPoints or 0
    player.baseMaxManaPoints = player.baseMaxManaPoints or 0
    player.baseDamagePoints = player.baseDamagePoints or 0
    player.baseMaxStaminaPoints = player.baseMaxStaminaPoints or 0
    player.baseSpeedPoints = player.baseSpeedPoints or 0

    -- Inicjalizacja aktualnych statystyk (pola, które są używane przez bars.lua/walkę)
    player.maxHp = player.maxHp or player.baseMaxHp
    player.hp = player.hp or player.maxHp
    player.maxMana = player.maxMana or player.baseMaxMana
    player.mana = player.mana or player.maxMana
    player.damage = player.damage or player.baseDamage
    player.speed = player.speed or player.baseSpeed
    player.maxStamina = player.maxStamina or player.baseMaxStamina
    
    -- Zapewnia, że gracz ma pola wymagane przez ten moduł
    player.currentLevel = player.currentLevel or 1
    player.currentXP = player.currentXP or 0
end

-- Funkcja dodająca XP (wywoływana po zabiciu wroga w enemieslogic.lua)
function Leveling:addXP(enemyId)
    if Leveling.currentLevel >= Leveling.levelCap then return end
    
    -- Na obecną chwilę, tylko Slime daje XP (wg. Twojej prośby)
    -- Możesz tu dodać logiczne sprawdzenie enemyId
    local xpGained = ENEMY_XP_VALUE 
    
    Leveling.currentXP = Leveling.currentXP + xpGained
    
    -- Sprawdzenie, czy nastąpił awans
    while Leveling.currentXP >= Leveling.XPToNextLevel do
        
        Leveling.currentLevel = Leveling.currentLevel + 1
        Leveling.attributePoints = Leveling.attributePoints + 1
        
        -- Przeniesienie nadmiarowego XP na następny poziom
        Leveling.currentXP = Leveling.currentXP - Leveling.XPToNextLevel
        
        -- Obliczenie nowego progu XP
        Leveling.XPToNextLevel = calculateXP(Leveling.currentLevel)
        
        -- Aktywacja okna ulepszeń
        Leveling.levelUpAvailable = true
        Leveling.selectedAttribute = 1 -- Resetowanie wybranego atrybutu przy awansie
        
        -- Ustawienie flagi w obiekcie gracza, jeśli potrzebne (np. do zatrzymania ruchu)
        player.isLevelingUp = true
        
        if Leveling.currentLevel >= Leveling.levelCap then break end
    end
end

-- Aktualizuje statystyki gracza po awansie
function Leveling:applyUpgrade(attributeKey)
    if Leveling.attributePoints < 1 then return end
    
    local upgrade = Leveling.upgradeStats[attributeKey]
    if not upgrade then return end
    
    local baseKey = upgrade.baseKey
    local pointsKey = baseKey .. "Points"

    if player[pointsKey] ~= nil then
        -- Zwiększenie punktów atrybutu (o 1, bo value=1% w Leveling.upgradeStats)
        player[pointsKey] = player[pointsKey] + upgrade.value
        
        -- Przeliczanie i zastosowanie zmian do statystyk gracza
        Leveling:recalculateStats(attributeKey)

        Leveling.attributePoints = Leveling.attributePoints - 1
        
        -- Jeśli wykorzystano wszystkie punkty, zamykamy okno
        if Leveling.attributePoints == 0 then
            Leveling.levelUpAvailable = false
            player.isLevelingUp = false
        end
    end
end

-- Obsługa klawiatury dla okna Level Up
function Leveling:keypressed(key)
    if not Leveling.levelUpAvailable then return end

    -- Użycie MapKey, jeśli jest dostępna globalnie (z main.lua)
    local mappedKey = _G.MapKey and _G.MapKey(key) or key
    local maxAttributes = #Leveling.attributes

    if mappedKey == "up" or key == "up" or mappedKey == "w" or key == "w" then
        Leveling.selectedAttribute = math.max(1, Leveling.selectedAttribute - 1)
    elseif mappedKey == "down" or key == "down" or mappedKey == "s" or key == "s" then
        Leveling.selectedAttribute = math.min(maxAttributes, Leveling.selectedAttribute + 1)
    elseif key == "return" or key == "space" or key == "kpenter" then 
        local attributeKey = Leveling.attributes[Leveling.selectedAttribute]
        Leveling:applyUpgrade(attributeKey)
    end
end


-- Obsługa kliknięcia myszą na przyciski ulepszeń
function Leveling:mousepressed(x, y, button)
    if not Leveling.levelUpAvailable or button ~= 1 then return end
    
    local win = Leveling.window
    local padding = 40
    local buttonH = 50
    
    -- POPRAWNE OBLICZANIE POZYCJI X I Y
    local screenWidth = love.graphics.getWidth()
    local winX = (screenWidth / 2) - (win.width / 2) -- Wyśrodkowanie poziome
    local winY = 50 -- Stała pozycja Y
    
    -- Przechodzimy przez przyciski
    for i, attr in ipairs(Leveling.attributes) do
        local btnY = winY + padding + (i * (buttonH + 10)) 
        local btnX = winX + 20 
        local btnW = win.width - 40
        
        if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + buttonH then
            -- Ustawienie wybranego atrybutu myszką
            Leveling.selectedAttribute = i
            Leveling:applyUpgrade(attr)
            return true
        end
    end
end


-- RYSOWANIE

function Leveling:draw()
    -- Rysuje pasek XP (zintegruj to w bars.lua później)
    self:drawXPBar()
    
    if not Leveling.levelUpAvailable then return end
    
    local win = Leveling.window
    local padding = 40
    local buttonH = 50

    -- POPRAWNE OBLICZANIE POZYCJI X I Y
    local screenWidth = love.graphics.getWidth()
    local winX = (screenWidth / 2) - (win.width / 2) -- Wyśrodkowanie poziome
    local winY = 50 -- Stała pozycja Y
    
    -- Przyciemnienie ekranu
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, love.graphics.getHeight())
    
    -- Tło okna
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", winX, winY, win.width, win.height, 10) 
    
    -- Ramka
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.rectangle("line", winX, winY, win.width, win.height, 10) 
    
    -- Tytuł
    love.graphics.setColor(1, 1, 1)
    local title = "LEVEL UP! (" .. Leveling.attributePoints .. " points)"
    love.graphics.printf(title, winX, winY + 10, win.width, "center") 
    
    -- Przyciski ulepszeń
    for i, attr in ipairs(Leveling.attributes) do
        local upgrade = Leveling.upgradeStats[attr]
        local btnY = winY + padding + (i * (buttonH + 10)) 
        local btnX = winX + 20 
        local btnW = win.width - 40
        
        -- Podświetlenie wybranego przycisku
        if i == Leveling.selectedAttribute then
            love.graphics.setColor(0.9, 0.5, 0.1, 1)
            love.graphics.rectangle("line", btnX - 5, btnY - 5, btnW + 10, buttonH + 10, 5)
        end
        
        -- Tło przycisku
        love.graphics.setColor(0.3, 0.3, 0.5)
        love.graphics.rectangle("fill", btnX, btnY, btnW, buttonH, 5)
        
        -- Ramka przycisku
        love.graphics.setColor(0.8, 0.8, 1)
        love.graphics.rectangle("line", btnX, btnY, btnW, buttonH, 5)
        
        -- Tekst przycisku
        love.graphics.setColor(1, 1, 1)
        local statText = string.format("%s", upgrade.name)
        love.graphics.printf(statText, btnX, btnY + 10, btnW, "center")
        
        -- Obecna wartość
        local currentVal
        if attr == "HP" then
            currentVal = player.maxHp
        elseif attr == "STR" then
            currentVal = player.damage
        elseif attr == "MANA" then
            currentVal = player.maxMana
        elseif attr == "STAMINA" then
            currentVal = player.maxStamina
        elseif attr == "SPEED" then
            currentVal = player.speed
        end
        
        local valText = string.format("Current: %d", math.floor(currentVal))
        love.graphics.printf(valText, btnX, btnY + 25, btnW, "center")
    end
    
    love.graphics.setColor(1, 1, 1) -- Reset koloru
end

-- Rysuje pasek XP
function Leveling:drawXPBar()
    local barWidth = 200
    local barHeight = 15
    local uiX = 10
    local uiY = 10 + 20 + 5 + 20 + 5 -- Pod Mana Bar
    
    local xpPercent = math.max(0, math.min(Leveling.currentXP / Leveling.XPToNextLevel, 1))

    -- Tło
    love.graphics.setColor(0.1, 0.1, 0.3)
    love.graphics.rectangle("fill", uiX, uiY, barWidth, barHeight, 3, 3)

    -- Wypełnienie XP
    love.graphics.setColor(0.2, 0.8, 0.8)
    love.graphics.rectangle("fill", uiX, uiY, xpPercent * barWidth, barHeight, 3, 3)

    -- Obramowanie
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", uiX, uiY, barWidth, barHeight, 3, 3)
    
    -- Tekst XP
    local xpText = string.format("Level %d | XP: %d / %d", 
                                 Leveling.currentLevel, 
                                 math.floor(Leveling.currentXP), 
                                 math.floor(Leveling.XPToNextLevel))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(xpText, uiX, uiY + barHeight/2 - 6, barWidth, "center")
end


return Leveling