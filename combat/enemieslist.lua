local EnemyDefinitions = {}

-- Zmienne globalne do późniejszego dostępu przez ID
EnemyDefinitions.SLIME_ID = "SLIME_01"
EnemyDefinitions.DUMMY_ID = "DUMMY_02"
EnemyDefinitions.BIGDUMMY_ID = "BIGDUMMY_03"


-- Tabela definicji bazowych statystyk dla każdego typu wroga
EnemyDefinitions.list = {
    [EnemyDefinitions.DUMMY_ID] = {
        name = "Dummy",
        maxHp = 200,
        width = 50, 
        height = 100,
        color = {0.9, 0, 0},
        dmgTextOffsetY = 30,
        isStatic = true,
        renderKey = "DUMMY_RENDER" 
    },
    
    [EnemyDefinitions.BIGDUMMY_ID] = {
        name = "Big Dummy",
        maxHp = 500,
        width = 100,
        height = 150,
        color = {1, 0, 0},
        dmgTextOffsetY = 30,
        isStatic = true,
        renderKey = "DUMMY_RENDER"
    },
    
    -- DEFINICJA SLIME'A
    [EnemyDefinitions.SLIME_ID] = {
        name = "White Slime",
        maxHp = 50, 
        width = 40, 
        height = 40,
        color = {1, 0, 0},
        dmgTextOffsetY = 10,
        isStatic = false, 
        renderKey = "SLIME_RENDER",
        
        -- Dodatkowe dane dla rendera Slime'a (animacja, skala, etc.)
        renderData = {
            spritePath = "sprites/slimesheet.png",
            frameWidth = 64,
            frameHeight = 64,
            maxFrames = 7,
            animationSpeed = 0.15,
            defaultScale = 4.0
        }
    }
}

return EnemyDefinitions