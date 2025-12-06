local EnemyDefinitions = {}

-- Zmienne globalne do późniejszego dostępu przez ID
EnemyDefinitions.SLIME_ID = "SLIME_01"          -- Biały Slime 
EnemyDefinitions.RED_SLIME_ID = "SLIME_02"      -- Czerwony Slime
EnemyDefinitions.BLUE_SLIME_ID = "SLIME_03"     -- Niebieski Wodny Slime
EnemyDefinitions.GREEN_SLIME_ID = "SLIME_04"     -- Zielony Slime
EnemyDefinitions.DUMMY_ID = "DUMMY_05"
EnemyDefinitions.BIGDUMMY_ID = "BIGDUMMY_06"


-- Tabela definicji bazowych statystyk dla każdego typu wroga
EnemyDefinitions.list = {
    [EnemyDefinitions.DUMMY_ID] = {
        name = "Dummy",
        maxHp = 200,
        width = 50, 
        height = 100,
        dmgTextOffsetY = 30,
        isStatic = true,
        renderKey = "DUMMY_RENDER" 
    },
    
    [EnemyDefinitions.BIGDUMMY_ID] = {
        name = "Big Dummy",
        maxHp = 500,
        width = 100,
        height = 150,
        dmgTextOffsetY = 30,
        isStatic = true,
        renderKey = "DUMMY_RENDER"
    },
    
    -- DEFINICJA BIAŁEGO SLIME'A (istniejący)
    [EnemyDefinitions.SLIME_ID] = {
        name = "White Slime",
        maxHp = 50, 
        width = 40, 
        height = 40,
        dmgTextOffsetY = 10,
        isStatic = false, 
        renderKey = "SLIME_RENDER",
        
        renderData = {
            spritePath = "sprites/basicslime.png",
            frameWidth = 64,
            frameHeight = 64,
            maxFrames = 7,
            animationSpeed = 0.15,
            defaultScale = 4.0
        }
    },
    
    -- DEFINICJA CZERWONEGO SLIME'A (Nowy - mocniejszy)
    [EnemyDefinitions.RED_SLIME_ID] = {
        name = "Red Slime",
        maxHp = 80, -- Więcej HP
        width = 45, 
        height = 45,
        dmgTextOffsetY = 10,
        isStatic = false, 
        renderKey = "SLIME_RENDER", -- Używa tego samego klucza renderowania
        
        renderData = {
            spritePath = "sprites/redslime.png", -- Możesz użyć innej ścieżki do tekstury
            frameWidth = 64,
            frameHeight = 64,
            maxFrames = 7,
            animationSpeed = 0.15,
            defaultScale = 4.5 -- Nieco większy
        }
    },
    
    -- DEFINICJA NIEBIESKIEGO SLIME'A (Nowy - słabszy/szybszy)
    [EnemyDefinitions.BLUE_SLIME_ID] = {
        name = "Blue Slime",
        maxHp = 40, -- Mniej HP
        width = 35, 
        height = 35,
        dmgTextOffsetY = 10,
        isStatic = false, 
        renderKey = "SLIME_RENDER", 
        
        renderData = {
            spritePath = "sprites/waterslime.png",
            frameWidth = 64,
            frameHeight = 64,
            maxFrames = 7,
            animationSpeed = 0.1, -- Szybsza animacja (może symulować szybkość)
            defaultScale = 3.5 -- Mniejszy
        }
    },
    
    -- DEFINICJA ZIELONEGO SLIME'A (Nowy - inny typ)
    [EnemyDefinitions.GREEN_SLIME_ID] = {
        name = "Green Slime",
        maxHp = 60, -- Przykładowa wartość HP
        width = 40, 
        height = 35,
        dmgTextOffsetY = 10,
        isStatic = false, 
        renderKey = "SLIME_RENDER", 
        
        renderData = {
            spritePath = "sprites/greenslime.png",
            frameWidth = 64,
            frameHeight = 64,
            maxFrames = 7,
            animationSpeed = 0.1, -- Szybsza animacja (może symulować szybkość)
            defaultScale = 3.5 -- Mniejszy
        }
    }
}

return EnemyDefinitions