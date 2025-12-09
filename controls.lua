local M = {}

local menuRef = nil
local activeTouches = {} 

-- Obiekt zarządzający kontrolkami dotykowymi
local touchControls = {}

-- Definicja przycisków dotykowych (współrzędne i akcje)
function touchControls.defineButtons(w, h)
	-- Używamy stałych wymiarów w pikselach dla lepszej kontroli na urządzeniach mobilnych
	local buttonSize = 90
	local dpadAreaSize = 180
	local padding = 20

	touchControls.buttons = {
		-- Wirtualny D-PAD (Lewy Dolny Róg)
		{ name = "DpadArea", x = padding, y = h - dpadAreaSize - padding, w = dpadAreaSize, h = dpadAreaSize, action = "move" },

		-- Przycisk Strzał / Akcja (Prawy Dolny Róg)
		{ name = "ActionA", x = w - buttonSize - padding, y = h - buttonSize - padding, w = buttonSize, h = buttonSize, action = "shoot" },
		
		-- Przycisk Ekwipunek / Przeładowanie (Prawy Środek)
		{ name = "ActionB", x = w - buttonSize - padding, y = h - 2 * buttonSize - 2 * padding, w = buttonSize, h = buttonSize, action = "inventory" },
	}
end

function touchControls.draw(game)
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	touchControls.defineButtons(w, h) 

	love.graphics.push()
	love.graphics.origin() 

	for _, button in ipairs(touchControls.buttons) do
		local color = {0.2, 0.2, 0.2, 0.7} 
		local isPressed = false
		
		for name, touch in pairs(activeTouches) do
			if name == button.name then
				isPressed = true
				break
			end
		end

		if isPressed then
			color = {0.8, 0.8, 0.8, 0.9} 
		end
		
		love.graphics.setColor(color)
		love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 10, 10)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 10, 10)
		
		-- Tekst/Nazwa przycisku
		love.graphics.setColor(1, 1, 1, 1)
		if button.name == "ActionA" then 
			love.graphics.printf("STRZAŁ", button.x, button.y + button.h / 2 - 10, button.w, "center")
		elseif button.name == "ActionB" then
			love.graphics.printf("E/R", button.x, button.y + button.h / 2 - 10, button.w, "center")
		elseif button.name == "DpadArea" then
			love.graphics.line(button.x + button.w/2, button.y, button.x + button.w/2, button.y + button.h)
			love.graphics.line(button.x, button.y + button.h/2, button.x + button.w, button.y + button.h/2)
		end
	end
	
	love.graphics.pop()
end

function touchControls.checkButton(x, y)
	for _, button in ipairs(touchControls.buttons) do
		if x >= button.x and x <= button.x + button.w and
			y >= button.y and y <= button.y + button.h then
			return button
		end
	end
	return nil
end

-- === PODSTAWOWE FUNKCJE MODUŁU ===

function M.init(menu)
	menuRef = menu
end

-- Tłumaczy wciśnięty klawisz na akcję 
function M.MapKey(key)
	if not menuRef or not menuRef.keyBindings then return key end
	for action, boundKey in pairs(menuRef.keyBindings) do
		if boundKey == key then
			return action:lower()
		end
	end
	return key
end

-- Zwraca klawisz przypisany do danej akcji 
function M.GetBoundKey(actionName)
	if not menuRef or not menuRef.keyBindings then return actionName:lower() end
	return menuRef.keyBindings[actionName]
end

function M.textinput(t, game)
	game.menu:textinput(t)
end

-- === LOGIKA KLAWIATURY ===

function M.keypressed(key, game)
	if key == "f3" then
		game.debugMode = not game.debugMode
		return
	end

	if game.state == "menu" then
		local action = game.menu:keypressed(key)
		if action == "start" and game.menu.nameEntered then
			game.state = "playing"
			game.player.name = game.menu.playerNameInput
		elseif action == "quit" then
			love.event.quit()
		end
	elseif game.state == "playing" then

		if game.leveling.levelUpAvailable then
			game.leveling:keypressed(key)
			return
		end

		local mappedKey = M.MapKey(key)

		if game.inventory.isOpen then
			if mappedKey == "inventory" or key == "e" then
				game.inventory:toggle()
			else
				game.inventory:keypressed(key)
			end
			return
		end

		if key == "1" then
			game.quickslots.currentSlot = 1
			game.quickslots:useCurrentSlot()
			return
		elseif key == "2" then
			game.quickslots.currentSlot = 2
			game.quickslots:useCurrentSlot()
			return
		elseif key == "3" then
			game.quickslots.currentSlot = 3
			game.quickslots:useCurrentSlot()
			return
		end

		game.player:keypressed(key)

		if mappedKey == "inventory" or key == "e" then
			game.inventory:toggle()
		elseif key == "escape" then
			game.state = "menu"
		end

		if key == "return" then
			if game.arcade:interact(game.player) then
				print("Player pressed Enter near arcade!")
				game.snake:load()
				game.state = "snake"
			end
		end

	elseif game.state == "snake" then
		game.snake:keypressed(key)
		if key == "escape" then
			game.state = "playing"
		end
	end
end

-- === LOGIKA MYSZY (KRYTYCZNA KOLEJNOŚĆ) ===

function M.mousepressed(x, y, button, game)
	
	-- 1. Levelowanie (najwyższy priorytet)
	if game.leveling.mousepressed(x, y, button) then return end

	-- 2. Obsługa przycisków HUD i ZATRZYMANIE, jeśli przycisk został trafiony.
	-- Wywołanie z 4 argumentami jest poprawne dla myszy: (x, y, button, game)
	if _G.buttonsUI and _G.buttonsUI.mousepressed(x, y, button, game) then 
		return 
	end

	-- 3. Menu (Logika menu jest zawsze obsługiwana, o ile nie zatrzymało jej Levelowanie/HUD)
	if game.state == "menu" then
		local action = game.menu:mousepressed(x, y, button)
		if action == "start" and game.menu.nameEntered then
			game.state = "playing"
			game.player.name = game.menu.playerNameInput
		elseif action == "quit" then
			love.event.quit()
		end
		return 
	end

	-- 4. Strzelanie/Gracz (TYLKO w stanie 'playing' i jeśli nic powyżej nie zatrzymało)
	if game.state == "playing" then
		game.player:mousepressed(x, y, button)
	end
end

function M.wheelmoved(x, y, game)
	if game.state == "playing" and not game.inventory.isOpen then
		local delta = 0
		if y > 0 then
			delta = -1
		elseif y < 0 then
			delta = 1
		end
		
		if delta ~= 0 then
			game.quickslots:changeSlot(delta)
		end
	end
end

-- === LOGIKA DOTYKU ===

function M.touchpressed(id, x, y, game)
	if game.state ~= "playing" then return end

	-- >>> Obsługa przycisków HUD (Konieczna zmiana! Wymuszamy 4 argumenty) <<<
	-- Dodajemy '1' jako fikcyjny argument 'button', aby 'game' trafiło na swoje miejsce w buttons.lua
	if _G.buttonsUI and _G.buttonsUI.mousepressed(x, y, 1, game) then 
		-- Rejestrujemy dotyk, aby zablokować touchreleased
		activeTouches["HUD"] = { id = id } 
		return 
	end
	
	local button = touchControls.checkButton(x, y)
	
	if button then
		activeTouches[button.name] = { id = id, x = x, y = y }
		
		if button.action == "shoot" then
			game.player:mousepressed(x, y, 1) 
		elseif button.action == "inventory" then
			if game.inventory.isOpen then
				game.inventory:toggle() 
			elseif _G.inventory and _G.inventory:getEquippedWeapon() and _G.inventory:getEquippedWeapon().data.name == "Shotgun" then
				game.player:keypressed('r')
			else
				game.inventory:toggle()
			end
		end
	
	elseif x < love.graphics.getWidth() / 2 then
		activeTouches["DpadArea"] = { id = id, x = x, y = y, initialX = x, initialY = y }
	end
end

function M.touchmoved(id, x, y, dx, dy, game)
	if game.state ~= "playing" then return end
	
	if activeTouches["DpadArea"] and activeTouches["DpadArea"].id == id then
		local initialX = activeTouches["DpadArea"].initialX
		local initialY = activeTouches["DpadArea"].initialY
		
		local diffX = x - initialX
		local diffY = y - initialY
		local threshold = 20 
		
		game.player.moveLeft = false
		game.player.moveRight = false
		game.player.moveUp = false
		game.player.moveDown = false
		
		if math.abs(diffX) > math.abs(diffY) and math.abs(diffX) > threshold then
			if diffX < 0 then game.player.moveLeft = true else game.player.moveRight = true end
		elseif math.abs(diffY) > threshold then
			if diffY < 0 then game.player.moveUp = true else game.player.moveDown = true end
		end
		
		activeTouches["DpadArea"].x = x
		activeTouches["DpadArea"].y = y
	end
end

function M.touchreleased(id, x, y, game)
	if game.state ~= "playing" then return end
	
	-- >>> ZWOLNIENIE PRZYCISKU HUD <<<
	if activeTouches["HUD"] and activeTouches["HUD"].id == id then
		activeTouches["HUD"] = nil
		return
	end
	
	for name, touch in pairs(activeTouches) do
		if touch.id == id then
			activeTouches[name] = nil
			
			if name == "DpadArea" then
				game.player.moveLeft = false
				game.player.moveRight = false
				game.player.moveUp = false
				game.player.moveDown = false
			end
			break
		end
	end
end

-- === FUNKCJA RYSOWANIA ===
M.draw = touchControls.draw

return M