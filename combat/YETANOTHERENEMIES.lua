local SlimeRenderer = {}
local slimeImage = nil
local quads = {}


function SlimeRenderer.load()
    local EnemyDefinitions = require("combat.enemieslist")
    local def = EnemyDefinitions.list[EnemyDefinitions.SLIME_ID].renderData -- Pobieramy dane dla Slime'a
    
    slimeImage = love.graphics.newImage(def.spritePath)
    
    -- Tworzenie Quadów
    for i = 0, def.maxFrames - 1 do
        table.insert(quads, love.graphics.newQuad(
            i * def.frameWidth, 
            0, 
            def.frameWidth, 
            def.frameHeight, 
            slimeImage:getDimensions()
        ))
    end
end

-- Aktualizacja animacji
function SlimeRenderer.updateSlimeAnimation(slime, dt)
    local EnemyDefinitions = require("combat.enemieslist")
    local def = EnemyDefinitions.list[slime.id].renderData 

    slime.animationTimer = slime.animationTimer + dt
    
    if slime.animationTimer >= def.animationSpeed then
        slime.animationTimer = slime.animationTimer - def.animationSpeed
        slime.currentFrame = slime.currentFrame + 1
        
        if slime.currentFrame > def.maxFrames then
            slime.currentFrame = 1
        end
    end
end


-- Rysowanie Slime'a
function SlimeRenderer.drawSlime(slime)
    if not slimeImage or not quads[slime.currentFrame] then return end
    
    local EnemyDefinitions = require("combat.enemieslist")
    local def = EnemyDefinitions.list[slime.id].renderData 

    local currentQuad = quads[slime.currentFrame]
    
    -- Korekta przesunięcia (Centrowanie animacji nad koliderem)
    local displayW = def.frameWidth * slime.scale
    local displayH = def.frameHeight * slime.scale
    local offsetX = (displayW - slime.w) / 2 
    local offsetY = (displayH - slime.h) / 2 
    
    -- Rysowanie animacji
    love.graphics.draw(
        slimeImage, 
        currentQuad, 
        slime.x - offsetX, 
        slime.y - offsetY, 
        0, 
        slime.scale, 
        slime.scale
    )

    -- RYSOWANIE PASKA HP
    local hpPerc = slime.hp / slime.maxHp
    local hpBarWidth = slime.w 
    local hpBarHeight = 5
    local hpBarY = slime.y - 10
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", slime.x, hpBarY, hpBarWidth, hpBarHeight)
    love.graphics.setColor(slime.color or {0, 0.8, 0.2}) 
    love.graphics.rectangle("fill", slime.x, hpBarY, hpBarWidth * hpPerc, hpBarHeight)

end

return SlimeRenderer