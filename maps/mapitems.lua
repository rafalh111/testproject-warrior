-- mapitems.lua
local MapItems = {}

-- KONFIGURACJA PRZEDMIOTÓW
local fixedSpawns = {
    -- Przykłady:
    { type = "Coin", x = 1024, y = 612 }
}

-- Funkcja tworząca obiekty na podstawie powyższej listy
function MapItems.init(gameMap, inventory, itemsData)
    inventory.itemsOnMap = {}

    for _, spawn in ipairs(fixedSpawns) do
        local itemData = itemsData[spawn.type]

        -- Sprawdzamy czy dany przedmiot istnieje w bazie danych itemów
        if itemData and itemData.image then
            -- Logika skali: moneta mniejsza, reszta większa (lub domyślna)
            local scale = spawn.type == "Coin" and 0.7 or 2.0
            
            local w, h = itemData.image:getWidth(), itemData.image:getHeight()
            local scaledW, scaledH = w * scale, h * scale
            
            table.insert(inventory.itemsOnMap, {
                itemType = spawn.type,
                data = itemData,
                x = spawn.x,
                y = spawn.y,
                width = scaledW,
                height = scaledH,
                scale = scale,
                amount = spawn.amount or 1, -- Tutaj przypisujemy ustaloną ilość
                collected = false
            })
        else
            print("[WARNING] MapItems: Nie znaleziono danych dla przedmiotu: " .. tostring(spawn.type))
        end
    end
    print("MapItems: Wygenerowano " .. #inventory.itemsOnMap)
end

-- Funkcja rysująca niezebrane przedmioty
function MapItems.draw(inventory)
    for _, item in ipairs(inventory.itemsOnMap) do
        if not item.collected and item.data and item.data.image then
            local scale = item.scale or 1
            -- Rysujemy obrazek w pozycji itemu (z lekkim offsetem, żeby x,y był środkiem, jeśli chcesz, tutaj rysuje od lewego górnego rogu)
            love.graphics.draw(item.data.image, item.x, item.y, 0, scale, scale)
            
        end
    end
end

return MapItems