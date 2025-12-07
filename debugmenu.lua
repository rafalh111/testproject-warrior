-- debugmenu.lua
local debugMenu = {}

function debugMenu.draw(player, cam, world, dungeon, inventory, arcade)
    local love = love -- lokalna referencja dla minimalnie szybszego dostępu

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 10, 60, 300, 580)
    love.graphics.setColor(1, 1, 1)
    
    local y = 65
    local function line(text)
        love.graphics.print(text, 15, y)
        y = y + 15
    end

    line("DEBUG MODE")
    line("Player name: " .. (player.name or "NO NAME"))
    line(string.format("FPS: %d | Δt: %.4f", love.timer.getFPS(), love.timer.getDelta()))
    line(string.format("Memory: %.2f MB", collectgarbage("count") / 1024))
    line("Draw calls: " .. love.graphics.getStats().drawcalls)
    
    -- Poprawne zliczanie ciał
    local totalWalls = 0
    if dungeon and dungeon.colliders then
        for _, chunkY in pairs(dungeon.colliders) do
            for _, wallsList in pairs(chunkY) do
                totalWalls = totalWalls + #wallsList
            end
        end
    end

    line(string.format("Bodies in world (Walls, Player Hitbox): " .. (totalWalls + 1))) 
    line(string.format("Camera: (%.1f, %.1f)", cam.x, cam.y))
    line(string.format("Player pos: (%.1f, %.1f)", player.x, player.y))
    
    if player.collider then
        local vx, vy = player.collider:getLinearVelocity()
        line(string.format("Velocity: (%.2f, %.2f)", vx, vy))
    end
    
    line("-----------------------------------")
    line("Items on map: " .. #inventory.itemsOnMap)
    line("Inventory slots: " .. #inventory.items)
    
    for i = 1, #inventory.items do
        if inventory.items[i] then
            local amt = inventory.items[i].amount or 1
            line("Slot " .. i .. ": " .. inventory.items[i].data.name .. " x" .. amt)
        end
    end
    
    if inventory.itemsOnMap[1] then
        local coin = inventory.itemsOnMap[1]
        line("-----------------------------------")
        line("Coin collected: " .. tostring(coin.collected))
        line("Coin data valid: " .. tostring(coin.data ~= nil))
        line("Coin canPickup: " .. tostring(coin.canPickup))
    end
    
    local uncollectedCoins = {}
    for _, item in ipairs(inventory.itemsOnMap) do
        if not item.collected then table.insert(uncollectedCoins, item) end
    end
    
    line("-----------------------------------")
    if #uncollectedCoins > 0 then
        local randomCoin = uncollectedCoins[math.random(1, #uncollectedCoins)]
        line("Random uncollected item:")
        line(string.format("Pos: (%.1f, %.1f)", randomCoin.x, randomCoin.y))
    else
        line("All items on map collected!")
    end
    
    love.graphics.setColor(1, 0.1, 0.1)
    love.graphics.print("[F3] DEBUG MODE ON", love.graphics.getWidth() - 180, 5)
    love.graphics.setColor(1, 1, 1)
    
    -- Rysowanie colliderów Windfielda
    cam:attach()
    world:draw()
    cam:detach()

    line("Arcade objects: " .. tostring(#arcade.objects))
    for _, obj in ipairs(arcade.objects) do
        if obj.triggered then
            line("-----------------------------------")
            line("Arcade: Player inside hitbox!")
            line("Press [Enter] to interact")
            break
        end
    end

    love.graphics.print("pre-alpha TestProject", 100, 65)
    love.graphics.print("Game made by:", 15, 610)
    love.graphics.print("Dorian Libertowicz & Rafał Hachuła 2025", 15, 620)
end

return debugMenu