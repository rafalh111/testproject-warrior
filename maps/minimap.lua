local minimap = {}

-- ZMIENNE MODUŁU, KTÓRE BĘDZIEMY AKTUALIZOWAĆ
local miniMapScale = 0.003
local miniMapX = 0
local miniMapY = 0
local miniMapWidth = 0
local miniMapHeight = 0
local padding = 20 -- Stałe odstępy od krawędzi

-- NOWA FUNKCJA: Wymusza przeliczenie pozycji/wymiarów minimapy
function minimap.recalculatePosition(gameMap)
    local screenW, screenH =
        love.graphics.getWidth(),
        love.graphics.getHeight()
    
    -- Musimy mieć pewność, że gameMap został przekazany do recalculatePosition
    if not gameMap or not gameMap.width then
        -- Jeśli gameMap nie jest dostępne w init (np. w love.load), ustawiamy domyślne 
        miniMapWidth = 200 -- Przykład domyślny, aby nie rzuciło błędu
        miniMapHeight = 200
    else
        -- Wymiary Mapy w pikselach
        miniMapWidth = gameMap.width * gameMap.tilewidth * miniMapScale
        miniMapHeight = gameMap.height * gameMap.tileheight * miniMapScale
    end

    -- POZYCJA MINIMAPY (PRAWY GÓRNY RÓG)
    miniMapX = screenW - miniMapWidth - padding
    miniMapY = padding
end

function minimap.draw(gameMap, player)
    
    -- WAŻNE: W LÖVE2D 'gameMap' zazwyczaj ma stałe wymiary, więc możemy je obliczać rzadziej.
    -- Jeśli jednak nie wiesz, czy 'recalculatePosition' było wywołane,
    -- bezpieczniej jest wywołać je tutaj, jeśli zmienne są niepoprawne:
    -- if miniMapX == 0 then minimap.recalculatePosition(gameMap) end 
    
    -- Używamy ZMIENNYCH MODUŁU zamiast lokalnych
    local currentMiniMapX = miniMapX
    local currentMiniMapY = miniMapY
    local currentMiniMapWidth = miniMapWidth
    local currentMiniMapHeight = miniMapHeight

    -- Jeśli skalowanie było zerowe (np. błąd w love.load), używamy aktualnych wymiarów
    if currentMiniMapWidth == 0 then
        minimap.recalculatePosition(gameMap)
        currentMiniMapX = miniMapX
        currentMiniMapY = miniMapY
        currentMiniMapWidth = miniMapWidth
        currentMiniMapHeight = miniMapHeight
    end

    -- TŁO
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle(
        "fill",
        currentMiniMapX - 4,
        currentMiniMapY - 4,
        currentMiniMapWidth + 8,
        currentMiniMapHeight + 8
    )

    -- POZYCJA GRACZA NA MINIMAPIE
    local playerMiniX =
        currentMiniMapX + (player.x * miniMapScale)

    local playerMiniY =
        currentMiniMapY + (player.y * miniMapScale)

    -- KROPKA GRACZA
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", playerMiniX, playerMiniY, 3)

    love.graphics.setColor(1, 1, 1, 1)
end

return minimap -- POPRAWKA: ZWRACAMY TABELĘ MODUŁU!