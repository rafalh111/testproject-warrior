local minimap = {}

function minimap.draw(gameMap, player)
    local miniMapScale = 0.003

    -- WYMIARY MAPY W PIKSELACH
    local miniMapWidth =
        gameMap.width * gameMap.tilewidth * miniMapScale

    local miniMapHeight =
        gameMap.height * gameMap.tileheight * miniMapScale

    local screenW, screenH =
        love.graphics.getWidth(),
        love.graphics.getHeight()

    -- POZYCJA MINIMAPY (PRAWY GÓRNY RÓG)
    local miniMapX = screenW - miniMapWidth - 20
    local miniMapY = 20

    -- TŁO
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle(
        "fill",
        miniMapX - 4,
        miniMapY - 4,
        miniMapWidth + 8,
        miniMapHeight + 8
    )

    -- POZYCJA GRACZA NA MINIMAPIE
    local playerMiniX =
        miniMapX + (player.x * miniMapScale)

    local playerMiniY =
        miniMapY + (player.y * miniMapScale)

    -- KROPKA GRACZA
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", playerMiniX, playerMiniY, 3)

    love.graphics.setColor(1, 1, 1, 1)
end

return minimap
