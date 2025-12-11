local bars = {}

-- 1. Definicja zmiennych, które będą przechowywać pozycje
local barX = 10
local barY = 10
local barWidth = 200
local barHeight = 20
local spacing = 5

-- NOWA FUNKCJA: Wymusza przeliczenie pozycji (choć w tym przypadku są stałe, to dobra praktyka)
function bars:recalculatePosition()
	-- Możesz to rozwinąć w przyszłości, aby obsłużyć kotwiczenie do prawej/dolnej krawędzi
	barX = 10 
	barY = 10
	
	-- TUTAJ DODAJESZ LOGIKĘ SKALOWANIA W PRZYSZŁOŚCI, np:
	-- barX = 10 * (_G.scale or 1)
	
	print("BARS RECALCULATE: Ustawiono stałe pozycje pasków (X=" .. barX .. ", Y=" .. barY .. ")") -- DIAGNOSTYKA
end

function bars:draw(player)
	
	-- Pasek BARS nie ustawia własnej czcionki, więc używa globalnej czcionki ustalonej w main.lua/menu
	local currentFont = love.graphics.getFont()

	-- Zamiast lokalnych zmiennych uiX, uiY, używamy zmiennych modułu
	local currentY = barY

	-- [[ HP BAR ]] --
	-- TŁO (jasno czerwone)
	love.graphics.setColor(0.9, 0.1, 0.1)
	love.graphics.rectangle("fill", barX, currentY, barWidth, barHeight, 3, 3)

	-- WYPEŁNIENIE (Czerwone)
	local hpPercent = math.max(0, math.min(player.hp / player.maxHp, 1))
	
	love.graphics.setColor(0.8, 0.1, 0.1)
	love.graphics.rectangle("fill", barX, currentY, hpPercent * barWidth, barHeight, 3, 3)

	-- OBRAMOWANIE
	love.graphics.setColor(1, 1, 1)
	love.graphics.rectangle("line", barX, currentY, barWidth, barHeight, 3, 3)

	-- TEKST HP 
	love.graphics.setColor(1, 1, 1)
	local hpText = math.floor(player.hp) .. " / " .. math.floor(player.maxHp)
	love.graphics.printf(hpText, barX, currentY + barHeight/2 - 6, barWidth, "center")


	-- [[ MANA BAR ]] --
	currentY = currentY + barHeight + spacing -- Używamy currentY, aby przesunąć w dół

	love.graphics.setColor(0.2, 0.2, 0.2)
	love.graphics.rectangle("fill", barX, currentY, barWidth, barHeight, 3, 3)

	local manaPercent = math.max(0, math.min(player.mana / player.maxMana, 1))

	love.graphics.setColor(0.1, 0.1, 0.8)
	love.graphics.rectangle("fill", barX, currentY, manaPercent * barWidth, barHeight, 3, 3)

	love.graphics.setColor(1, 1, 1)
	love.graphics.rectangle("line", barX, currentY, barWidth, barHeight, 3, 3)

	local manaText = math.floor(player.mana) .. " / " .. math.floor(player.maxMana)
	love.graphics.printf(manaText, barX, currentY + barHeight/2 - 6, barWidth, "center")
end

return bars