local bars = {}

-- 1. Definicja zmiennych
local barX = 10
local barY = 10
local barWidth = 200
local barHeight = 20
local spacing = 5

-- Stałe dla segmentów
local SEGMENT_SIZE = 20    -- Ilość jednostek (HP/Mana) na jeden segment
local SEGMENT_SPACING = 1  -- Szerokość spacji/separatora między segmentami w pixelach
local GRADIENT_STEPS = 100 -- Zwiększamy kroki, aby gradient był bardzo płynny
local ANIMATION_SPEED = 3.0 -- Szybkość, z jaką pulsuje/zmienia się gradient
local COLOR_INTENSITY = 0.2 -- Jak duży jest zakres zmiany koloru

function bars:recalculatePosition()
    barX = 10 
    barY = 10
end

-- Funkcja do interpolacji liniowej kolorów (Lerp)
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Funkcja pomocnicza do rysowania paska z segmentami i PŁYNNYM animowanym gradientem
local function drawAnimatedSegmentedBar(player, statValue, statMax, barYPos, baseColor)
    
    local time = love.timer.getTime()
    
    -- 1. Rysowanie TŁA i Segmentów (logika segmentów zostaje, ale bez własnego gradientu)
    
    local totalSegments = math.ceil(statMax / SEGMENT_SIZE)
    local totalSpacingWidth = (totalSegments - 1) * SEGMENT_SPACING
    local individualSegmentWidth = (barWidth - totalSpacingWidth) / totalSegments

    local segmentX = barX
    
    for i = 1, totalSegments do
        local currentSegmentWidth = individualSegmentWidth
        if i == totalSegments then
            currentSegmentWidth = barX + barWidth - segmentX
        end
        
        -- Rysowanie tła segmentu (czarny/ciemny dla nieuzupełnionej sekcji)
        love.graphics.setColor(0.1, 0.1, 0.1) 
        love.graphics.rectangle("fill", segmentX, barYPos, currentSegmentWidth, barHeight, 3, 3)
        
        -- Rysowanie białego separatora
        if i < totalSegments then
            love.graphics.setColor(1, 1, 1) -- Biały kolor
            love.graphics.rectangle("fill", segmentX + currentSegmentWidth, barYPos, SEGMENT_SPACING, barHeight, 0, 0)
        end
        
        segmentX = segmentX + individualSegmentWidth + SEGMENT_SPACING
    end
    
    -- 2. Rysowanie WYPEŁNIENIA z PŁYNNYM GRADIENTEM na CAŁEJ SZEROKOŚCI
    
    local fillWidth = math.min(1, statValue / statMax) * barWidth
    local stepWidth = fillWidth / GRADIENT_STEPS

    for j = 0, GRADIENT_STEPS - 1 do
        
        local stepX = barX + j * stepWidth
        local actualStepWidth = stepWidth
        
        -- Korekta dla ostatniego kroku
        if j == GRADIENT_STEPS - 1 then
            actualStepWidth = barX + fillWidth - stepX
        end
        
        -- WSPÓŁRZĘDNA GLOBALNA dla koloru (od 0.0 do 1.0 na całym wypełnieniu)
        local t_global = (stepX - barX) / barWidth 
        
        -- A. Wprowadzenie animacji koloru (pulsowanie/zmiana w czasie)
        -- Używamy sinusa do stworzenia płynnej, cyklicznej zmiany
        local pulse = math.sin(time * ANIMATION_SPEED + t_global * 5.0) * COLOR_INTENSITY / 2.0 
        
        -- B. Ostateczny kolor (gradient + animacja)
        
        -- Używamy t_global do płynnego przejścia koloru bazowego od lewej do prawej
        local intensity = 0.5 * t_global -- Lżejszy gradient od lewej do prawej
        
        local r = baseColor[1] + intensity + pulse
        local g = baseColor[2] + intensity + pulse
        local b = baseColor[3] + intensity + pulse
        
        -- Ograniczenie kolorów do zakresu 0-1
        r = math.min(1, math.max(0, r))
        g = math.min(1, math.max(0, g))
        b = math.min(1, math.max(0, b))
        
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", stepX, barYPos, actualStepWidth, barHeight, 0, 0)
    end
    
    -- 3. Rysowanie obramowania CAŁEGO paska na koniec (nie segmentów)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", barX, barYPos, barWidth, barHeight, 3, 3)
end


function bars:draw(player)
    
    local currentY = barY
    
    -- [[ HP BAR ]] --
    
    -- Kolor bazowy HP (ciemna czerwień)
    local hpBaseColor = {0.6, 0.0, 0.0}
    
    drawAnimatedSegmentedBar(
        player, 
        player.hp, 
        player.maxHp, 
        currentY, 
        hpBaseColor
    )

    -- TEKST HP 
    love.graphics.setColor(1, 1, 1)
    local hpText = math.floor(player.hp) .. " / " .. math.floor(player.maxHp)
    love.graphics.printf(hpText, barX, currentY + barHeight/2 - 6, barWidth, "center")

    -- [[ MANA BAR ]] --
    currentY = currentY + barHeight + spacing -- Przesunięcie w dół

    -- Kolor bazowy MANA (ciemny niebieski)
    local manaBaseColor = {0.0, 0.0, 0.6}
    
    drawAnimatedSegmentedBar(
        player, 
        player.mana, 
        player.maxMana, 
        currentY, 
        manaBaseColor
    )

    -- TEKST MANA 
    love.graphics.setColor(1, 1, 1)
    local manaText = math.floor(player.mana) .. " / " .. math.floor(player.maxMana)
    love.graphics.printf(manaText, barX, currentY + barHeight/2 - 6, barWidth, "center")
end

return bars