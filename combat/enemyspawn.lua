-- File: EnemySpawn.lua

local EnemySpawn = {}

-- Funkcja do spawnowania początkowej fali wrogów
function EnemySpawn.spawnInitialWave(enemies, EnemyDefinitions)
    -- Lista wszystkich ID Slime'ów, które chcemy losować
    local slimeTypes = {
        EnemyDefinitions.SLIME_ID,
        EnemyDefinitions.RED_SLIME_ID,
        EnemyDefinitions.BLUE_SLIME_ID,
        EnemyDefinitions.GREEN_SLIME_ID
    }

    -- Liczba dostępnych typów Slime'ów
    local numSlimeTypes = #slimeTypes

    -- Lokalizacja spawnu (centrum, np. 100, 100)
    local centerX = 1200
    local centerY = 1200
    local spawnRadius = 500 -- Promień, w którym Slime'y będą się pojawiać
    local count = 100 -- Liczba Slime'ów do spawnowania

    -- Spawnowanie jednego Slime'a w centrum (jako "lider")
    enemies:spawnEnemy(EnemyDefinitions.SLIME_ID, centerX, centerY, nil, nil)

    -- Pętla tworząca dodatkowe wrogów
    for i = 1, count do
        -- Losowanie pozycji w promieniu
        local randomX = centerX + love.math.random(-spawnRadius, spawnRadius)
        local randomY = centerY + love.math.random(-spawnRadius, spawnRadius)

        -- Losowanie indeksu z listy typów Slime'ów
        local randomIndex = love.math.random(1, numSlimeTypes)
        
        -- Pobranie wylosowanego ID Slime'a
        local randomSlimeID = slimeTypes[randomIndex]

        -- Spawnowanie wylosowanego Slime'a
        enemies:spawnEnemy(randomSlimeID, randomX, randomY, nil, nil)
    end
end

return EnemySpawn