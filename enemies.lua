local enemies = {}
local player = require("player")

-- Tabela definicji bazowych statystyk dla każdego typu wroga
local ENEMY_DEFINITIONS = {
    dummy = {
        maxHp = 200,
        width = 50, 
        height = 100,
        color = {0.9, 0, 0},
        dmgTextOffsetY = 30
    },
    bigDummy = {
        maxHp = 500,
        width = 100,
        height = 150,
        color = {1, 0, 0},
        dmgTextOffsetY = 30
    }
    
}

function enemies:init(world)
    self.world = world
    self.list = {}
    self.damageTexts = {}
end

-- Funkcja pomocnicza do tworzenia dowolnego wroga
local function createEnemy(self, type, x, y, w, h)
    local def = ENEMY_DEFINITIONS[type]
    if not def then
        print("Error: Unknown enemy type: " .. type)
        return
    end

    local width = w or def.width
    local height = h or def.height
    
    local enemy = {
        x = x,
        y = y,
        w = width,
        h = height,
        hp = def.maxHp,
        maxHp = def.maxHp,
        type = type,
        color = def.color,
        damageTakenThisFrame = 0,
        dmgTextOffsetY = def.dmgTextOffsetY,
        
        collider = self.world:newRectangleCollider(x, y, width, height)
    }

    enemy.collider:setType("static")
    enemy.collider:setCollisionClass("Enemy")
    enemy.collider.parent = enemy 

    table.insert(self.list, enemy)
end

-- Funkcja do spawnowania "Dummy"
function enemies:spawnDummy(x, y, w, h)
    createEnemy(self, "dummy", x, y, w, h)
end

-- Funkcja do spawnowania "BigDummy"
function enemies:spawnBigDummy(x, y, w, h)
    createEnemy(self, "bigDummy", x, y, w, h)
end

-- Sumowanie dmg
function enemies:takeDamage(enemy)
    local dmg = player.damage or 1 

    enemy.hp = enemy.hp - dmg 
    enemy.damageTakenThisFrame = enemy.damageTakenThisFrame + dmg 
    
    if enemy.hp <= 0 then
        enemy.hp = enemy.maxHp
    end
end

function enemies:update(dt)
    -- Przetwarzanie sumarycznych obrażeń na koniec klatki
    for _, e in ipairs(self.list) do
        if e.damageTakenThisFrame > 0 then
            -- 1.tekst DMG
            table.insert(self.damageTexts, {
                x = e.x + e.w / 2, 
                -- Pozycja Y = Góra wroga (e.y) minus offset (e.dmgTextOffsetY)
                y = e.y - e.dmgTextOffsetY, 
                dmg = math.floor(e.damageTakenThisFrame),
                timer = 0.5,
                vy = -30,
                color = e.color or {1, 1, 0}
            })
            
            -- 2.licznik obrażeń na następną klatkę
            e.damageTakenThisFrame = 0 
        end
    end

    -- update floating damage texts (ruch)
    for i = #self.damageTexts, 1, -1 do
        local t = self.damageTexts[i]
        t.y = t.y + t.vy * dt
        t.timer = t.timer - dt
        if t.timer <= 0 then
            table.remove(self.damageTexts, i)
        end
    end
end

function enemies:draw()
    -- rysowanie przeciwników i pasków HP
    for _, e in ipairs(self.list) do
        local hpPerc = e.hp / e.maxHp
        local hpBarWidth = e.w 
        local hpBarHeight = 5
        local hpBarY = e.y - 10

        -- Tło paska HP
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", e.x, hpBarY, hpBarWidth, hpBarHeight)

        -- Wypełnienie HP
        love.graphics.setColor(e.color or {0, 1, 0}) 
        love.graphics.rectangle("fill", e.x, hpBarY, hpBarWidth * hpPerc, hpBarHeight)

        -- DEBUG: Rysowanie prostokąta wroga
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("line", e.x, e.y, e.w, e.h)
    end

    -- rysowanie floating damage text
    for _, t in ipairs(self.damageTexts) do
        -- Rysowanie tekstu DMG
        love.graphics.setColor(t.color or {1, 1, 0}) 
        
        love.graphics.printf(
            tostring(math.floor(t.dmg)), 
            t.x - 50, 
            t.y, 
            100, 
            "center"
        ) 
    end
    
    love.graphics.setColor(1, 1, 1) 
end

return enemies