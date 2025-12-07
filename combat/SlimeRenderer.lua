-- File: SlimeRenderer.lua (ZMIENIONY)

local SlimeRenderer = {}
local loadedResources = {} -- Nowa tabela: przechowuje {Image, Quads, Definicja} dla każdego spritePath

-- Inicjalizacja (wymagana do przechowywania Definicji)
function SlimeRenderer.init(EnemyDefinitions)
    SlimeRenderer.EnemyDefs = EnemyDefinitions
end

function SlimeRenderer.load()
    local EnemyDefinitions = SlimeRenderer.EnemyDefs or require("combat.enemieslist")
    
    -- Iterujemy po WSZYSTKICH definicjach, aby załadować wszystkie unikalne sprite'y Slime'ów
    for id, def in pairs(EnemyDefinitions.list) do
        if def.renderKey == "SLIME_RENDER" and def.renderData then
            local path = def.renderData.spritePath
            
            if not loadedResources[path] then
                
                -- 1. Ładowanie obrazu
                local image = love.graphics.newImage(path)
                local quads = {}
                
                -- 2. Tworzenie Quadów dla TEGO KONKRETNEGO sprite'u
                for i = 0, def.renderData.maxFrames - 1 do
                    table.insert(quads, love.graphics.newQuad(
                        i * def.renderData.frameWidth, 
                        0, 
                        def.renderData.frameWidth, 
                        def.renderData.frameHeight, 
                        image:getDimensions()
                    ))
                end
                
                -- 3. Zapisanie zasobów pod unikalną ścieżką
                loadedResources[path] = {
                    image = image,
                    quads = quads,
                    data = def.renderData -- Zapisujemy definicję klatek
                }
            end
        end
    end
end

-- Aktualizacja animacji (prawie bez zmian, używamy danych z wroga)
function SlimeRenderer.updateSlimeAnimation(slime, dt)
    -- Używamy ZAPISANEGO renderData, aby uniknąć zbędnego require w pętli update
    local def = slime.renderData or SlimeRenderer.EnemyDefs.list[slime.id].renderData 

    slime.animationTimer = slime.animationTimer + dt
    
    if slime.animationTimer >= def.animationSpeed then
        slime.animationTimer = slime.animationTimer - def.animationSpeed
        slime.currentFrame = (slime.currentFrame % def.maxFrames) + 1 -- Uproszczona logika ramki
    end
end


-- Rysowanie Slime'a
function SlimeRenderer.drawSlime(slime)
    -- Pobieramy zasoby na podstawie unikalnej ścieżki sprite'u
    local path = slime.renderData.spritePath
    local res = loadedResources[path]
    
    if not res or not res.quads[slime.currentFrame] then return end
    
    local def = res.data -- Używamy załadowanych danych klatek
    local currentQuad = res.quads[slime.currentFrame]
    
    -- ... reszta logiki rysowania (korekta przesunięcia jest OK)
    
    -- Korekta przesunięcia (Centrowanie animacji nad koliderem)
    local displayW = def.frameWidth * slime.scale
    local displayH = def.frameHeight * slime.scale
    local offsetX = (displayW - slime.w) / 2 
    local offsetY = (displayH - slime.h) / 2 
    
    -- Rysowanie animacji
    love.graphics.draw(
        res.image, -- Używamy właściwego obrazu
        currentQuad, 
        slime.x - offsetX, 
        slime.y - offsetY, 
        0, 
        slime.scale, 
        slime.scale
    )

    -- RYSOWANIE PASKA HP
    local hpPerc = slime.hp / slime.maxHp
    -- Tylko rysujemy, jeśli HP jest mniejsze niż maxHP (opcjonalnie)
    if hpPerc < 1 then 
        local hpBarWidth = slime.w 
        local hpBarHeight = 5
        local hpBarY = slime.y - 10
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8) -- Ciemne tło
        love.graphics.rectangle("fill", slime.x, hpBarY, hpBarWidth, hpBarHeight)
        
        -- Używamy ZIELONEGO jako domyślny kolor paska HP (zamiast nieustawionego slime.color)
        love.graphics.setColor({0, 0.8, 0.2}) 
        
        love.graphics.rectangle("fill", slime.x, hpBarY, hpBarWidth * hpPerc, hpBarHeight)
    end
    -- Ważne: Zresetuj kolor na biały po rysowaniu UI, aby nie zepsuć następnego renderowania
    love.graphics.setColor(1, 1, 1) 

end

return SlimeRenderer