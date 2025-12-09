local M = {}

-- Obrazy przycisków
local optionsIcon = nil
local inventoryIcon = nil
local iconSize = 32
local padding = 10

-- Współrzędne i akcje przycisków
local hudElements = {} 

function M.load()
	optionsIcon = love.graphics.newImage("sprites/optionsicon.png")
	inventoryIcon = love.graphics.newImage("sprites/inventoryicon.png")
end

function M.draw(game)
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	
	-- Pobranie pozycji myszy (lub dotyku)
	local mx, my = love.mouse.getPosition()
	
	-- Używamy tymczasowej tabeli w tej klatce, aby zbierać dane.
	local tempHudElements = {} 
	
	-- Stała pozycja Y
	local commonY = padding + 70 
	
	-- === 1. PRZYCISK OPCJE/MENU (Lewa Strona) ===
	local optionsX = padding 
	local optionsY = commonY

	local optionsBtn = {
		name = "options",
		x = optionsX,
		y = optionsY,
		w = iconSize,
		h = iconSize,
		action = "open_menu"
	}
	table.insert(tempHudElements, optionsBtn)

	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(optionsIcon, optionsX, optionsY, 0, iconSize / optionsIcon:getWidth(), iconSize / optionsIcon:getHeight())
	
	-- === RYSOWANIE RAMKI HOVER DLA OPCJI ===
	-- Używamy tymczasowej listy do sprawdzenia najechania kursorem
	if M.checkHit(mx, my, tempHudElements) == optionsBtn then 
		love.graphics.setColor(1, 1, 0, 1) -- Żółty kolor
		love.graphics.setLineWidth(2) 
		love.graphics.rectangle("line", optionsX, optionsY, iconSize, iconSize) 
		love.graphics.setLineWidth(1)
	end
	
	love.graphics.setColor(1, 1, 1) -- Reset koloru


	-- === 2. PRZYCISK EKWIPUNEK/INVENTORY (Obok Opcji) ===
	local inventoryX = optionsX + iconSize + padding 
	local inventoryY = commonY
	
	local inventoryBtn = {
		name = "inventory",
		x = inventoryX,
		y = inventoryY,
		w = iconSize,
		h = iconSize,
		action = "toggle_inventory"
	}
	table.insert(tempHudElements, inventoryBtn)

	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(inventoryIcon, inventoryX, inventoryY, 0, iconSize / inventoryIcon:getWidth(), iconSize / inventoryIcon:getHeight())
	
	-- === RYSOWANIE RAMKI HOVER DLA EKWIPUNKU ===
	if M.checkHit(mx, my, tempHudElements) == inventoryBtn then 
		love.graphics.setColor(1, 1, 0, 1) -- Żółty kolor
		love.graphics.setLineWidth(2) 
		love.graphics.rectangle("line", inventoryX, inventoryY, iconSize, iconSize)
		love.graphics.setLineWidth(1)
	end

	love.graphics.setColor(1, 1, 1) 

	-- KLUCZOWA ZMIANA: Przypisz elementy HUD na koniec rysowania
	hudElements = tempHudElements

	-- Debug (opcjonalnie)
	if game and game.debugMode then
		love.graphics.setColor(1, 0, 0, 0.5)
		for _, btn in ipairs(hudElements) do 
			love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
		end
		love.graphics.setColor(1, 1, 1)
	end
end

-- Sprawdza, czy koordynaty (x, y) trafiają w któryś z przycisków
function M.checkHit(x, y, elements)
	-- Użyj listy elementów przekazanej do funkcji lub globalnej listy
	local list = elements or hudElements 
	
	if type(x) ~= 'number' or type(y) ~= 'number' then
		return nil
	end

	for i, btn in ipairs(list) do 
		
		if type(btn) ~= 'table' then goto continue end

		local btn_x = tonumber(btn.x)
		local btn_y = tonumber(btn.y)
		local btn_w = tonumber(btn.w)
		local btn_h = tonumber(btn.h)
		
		if btn_x and btn_y and btn_w and btn_h then
			
			if x >= btn_x and x <= btn_x + btn_w and
				y >= btn_y and y <= btn_y + btn_h then
				return btn
			end
		end
		
		::continue::
	end
	return nil
end

-- Obsługa kliknięcia (TERAZ BEZPOŚREDNIO WYWOŁUJEMY AKCJĘ)
function M.mousepressed(x, y, button, game) 
	
	local clickX = tonumber(x)
	local clickY = tonumber(y)
	
	-- Wychodzimy, jeśli brakuje danych LUB 'game' nie jest tabelą (zabezpieczenie przed błędami argumentów)
	if clickX == nil or clickY == nil or type(game) ~= "table" then
		return false
	end
	
	print("DEBUG (Buttons): M.mousepressed called at X:" .. clickX .. " Y:" .. clickY) 
	
	local hit = M.checkHit(clickX, clickY) 
	
	if hit then
		print("DEBUG (Buttons): Hit button: " .. hit.name .. " (Direct action)")

		-- Weryfikujemy, czy moduły są dostępne
		if game.inventory and game.inventory.toggle then
			
			if hit.action == "toggle_inventory" then
				-- BEZPOŚREDNIE WYWOŁANIE (Najpewniejsza metoda!)
				game.inventory:toggle()
				print("DEBUG (Buttons): Inventory toggled successfully.")
				return true
			
			elseif hit.action == "open_menu" then
				-- BEZPOŚREDNIA ZMIANA STANU GRY
				game.state = "menu"
				print("DEBUG (Buttons): Game state changed to menu.")
				return true
			end
		else
			print("ERROR (Controls): Game object or inventory module is missing or corrupted.")
		end
	else
		print("DEBUG (Buttons): M.checkHit returned nil (no button hit).") 
	end
	return false
end

return M