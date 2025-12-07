local arcade = {}

-- Lista wszystkich arcade obiektów
arcade.objects = {}

-- Inicjalizacja arcade
function arcade:load(world, map)
    self.objects = {}

    if map.layers["Arcade"] then
        for _, obj in pairs(map.layers["Arcade"].objects) do
            local w, h = obj.width or 128, obj.height or 128
            local x, y = obj.x or 0, obj.y or 0
            table.insert(self.objects, {
                x = x,
                y = y,
                width = w,
                height = h,
                image = love.graphics.newImage("sprites/arcade.png"),
                triggered = false,
            })
        end
    end
end

-- Aktualizacja arcade, np. sprawdzanie kolizji z graczem
function arcade:update(dt, player)
    for _, obj in ipairs(self.objects) do
        if player.collider then
            local px, py = player.collider:getPosition() -- Prawdziwa pozycja gracza
            local pw, ph = player.width or 32, player.height or 48 -- wymiary sprite’a

            -- Zakładamy, że obj.x,obj.y to lewy-górny róg hitboxa arcade
            if px + pw / 2 > obj.x and px - pw / 2 < obj.x + obj.width and
               py + ph / 2 > obj.y and py - ph / 2 < obj.y + obj.height then
                obj.triggered = true
            else
                obj.triggered = false
            end
        end
    end
end


-- Rysowanie arcade
function arcade:draw(debugMode)
    for _, obj in ipairs(self.objects) do
        -- Rysowanie obrazka z dopasowaną skalą
        local scaleX = obj.width / obj.image:getWidth()
        local scaleY = obj.height / obj.image:getHeight()
        love.graphics.draw(obj.image, obj.x, obj.y, 0, scaleX, scaleY)

        -- Hitbox w trybie debug
        if debugMode then
            love.graphics.setColor(1, 0, 0, 0.5)
            love.graphics.rectangle("line", obj.x, obj.y, obj.width, obj.height)
            love.graphics.setColor(1, 1, 1)
        end

        -- Opcjonalne oznaczenie aktywnego arcade
        if obj.triggered and debugMode then
            love.graphics.setColor(0, 1, 0, 0.5)
            love.graphics.rectangle("line", obj.x, obj.y, obj.width, obj.height)
            love.graphics.setColor(1, 1, 1)
        end
    end
end

function arcade:interact(player)
    for _, obj in ipairs(self.objects) do
        if obj.triggered then
            print("Arcade interaction triggered!")  -- test w konsoli
            -- tutaj możesz później dodać np. zmianę stanu gry:
            -- gameState = "snake"
            return true
        end
    end
    return false
end


return arcade
