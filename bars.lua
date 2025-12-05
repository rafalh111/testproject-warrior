local bars = {}

function bars:draw(player)
    local barWidth = 200
    local barHeight = 20
    local spacing = 5
    local uiX = 10
    local uiY = 10

    -- [[ HP BAR ]] --
    -- TŁO (jasno czerwone) - zawsze rysuje się na pełną szerokość, iluzja dodatkowe hp xdddd
    love.graphics.setColor(0.9, 0.1, 0.1)
    love.graphics.rectangle("fill", uiX, uiY, barWidth, barHeight, 3, 3)

    -- WYPEŁNIENIE (Czerwone)
    local hpPercent = math.max(0, math.min(player.hp / player.maxHp, 1))
    
    love.graphics.setColor(0.8, 0.1, 0.1)
    love.graphics.rectangle("fill", uiX, uiY, hpPercent * barWidth, barHeight, 3, 3)

    -- OBRAMOWANIE
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", uiX, uiY, barWidth, barHeight, 3, 3)

    -- TEKST HP 
    love.graphics.setColor(1, 1, 1)
    local hpText = math.floor(player.hp) .. " / " .. math.floor(player.maxHp)
    love.graphics.printf(hpText, uiX, uiY + barHeight/2 - 6, barWidth, "center")


    -- [[ MANA BAR ]] --
    uiY = uiY + barHeight + spacing

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", uiX, uiY, barWidth, barHeight, 3, 3)

    local manaPercent = math.max(0, math.min(player.mana / player.maxMana, 1))

    love.graphics.setColor(0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", uiX, uiY, manaPercent * barWidth, barHeight, 3, 3)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", uiX, uiY, barWidth, barHeight, 3, 3)

    -- Tutaj miałeś już math.floor przy manie, ale warto też dać przy maxMana
    local manaText = math.floor(player.mana) .. " / " .. math.floor(player.maxMana)
    love.graphics.printf(manaText, uiX, uiY + barHeight/2 - 6, barWidth, "center")
end

return bars