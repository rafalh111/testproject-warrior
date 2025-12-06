-- main.lua
local wf = require "libraries/windfield"
local camera = require "libraries/camera"
local anim8 = require "libraries/anim8"
local sti = require "libraries/sti"
local utf8 = require("utf8")
local arcade = require("minigry.arcade")
local snake = require("minigry.snake")
local dungeon = require("maps.dungeon")
local bullets = require("combat.bullets")
enemies = require("combat.enemieslogic")
local EnemyDefinitions = require("combat.enemieslist")
local yetAnotherEnemies = require("combat.yetanotherenemies")
local player = require("playerstuff.player")
local leveling = require("playerstuff.leveling")
local EnemySpawn = require("combat.enemyspawn")

-- Player name
playerName = ""

-- Globalna funkcja 1: Tłumaczy wciśnięty klawisz)
function MapKey(key)
	-- Zabezpieczenie przed wywołaniem przed załadowaniem menu
	if not menu or not menu.keyBindings then return key end
	for action, boundKey in pairs(menu.keyBindings) do
		if boundKey == key then
			return action:lower()
		end
	end
	return key
end

-- Globalna funkcja 2: Zwraca klawisz przypisany do danej akcji
function GetBoundKey(actionName)
	-- Zabezpieczenie przed wywołaniem przed załadowaniem menu
	if not menu or not menu.keyBindings then return actionName:lower() end
	return menu.keyBindings[actionName]
end

function love.load()

	gameMap = {
    layers = {},
    width = 1024,
    height = 1024,
    tilewidth = 64,
    tileheight = 64
	}


	love.graphics.setDefaultFilter("nearest", "nearest")

	world = wf.newWorld(0, 0)

	dungeon.setPhysicsWorld(world)

	-- REJESTRACJA KLAS KOLIZJI
	world:addCollisionClass('Player')
	world:addCollisionClass('Enemy')
	world:addCollisionClass('Bullet')
	world:addCollisionClass('Wall')

	cam = camera()

	bullets:init(world, enemies, player)-- 1. Inicjalizacja świata Windfielda dla pocisków
	bullets:load()-- 2. Załadowanie innych zasobów
	enemies:init(world)-- 3. Inicjalizacja świata Windfielda dla wrogów

	EnemySpawn.spawnInitialWave(enemies, EnemyDefinitions)
	
	menu = require("menu")
	gameState = "menu"
	menu:init()

	-- Inventory
	inventory = require("playerstuff.inventory")
	inventory:init()

	-- Ładujemy dane itemów i obrazki
	itemsData = require("playerstuff.items")
	itemsData:loadImages()

	-- startowe itemy
	inventory.items = {}

	local startingItems = {
		"BUZZGAREN",
		"StaminaRing",
		"helmet",
		"chestplate",
		"leggins",
		"boots",
		"Shotgun",
		"AssaultRifle"
	}

	for i, itemName in ipairs(startingItems) do
		inventory.items[i] = {
			itemType = itemName,
			data = itemsData[itemName],
			equipped = false,
			amount = 1
		}
	end

	leveling:init(player)

	-- Items on map
	inventory.itemsOnMap = {}

	local mapItemLayers = { "Coin", "AssaultRifle" }

	for _, layerName in ipairs(mapItemLayers) do
		if gameMap.layers[layerName] then
			for _, obj in pairs(gameMap.layers[layerName].objects) do
				local scale = layerName == "Coin" and 0.7 or 2.0
				local itemData = itemsData[layerName]
				if itemData and itemData.image then
					local w, h = itemData.image:getWidth(), itemData.image:getHeight()
					local scaledW, scaledH = w * scale, h * scale
					table.insert(inventory.itemsOnMap, {
						itemType = layerName,
						data = itemData,
						x = obj.x,
						y = obj.y,
						width = scaledW,
						height = scaledH,
						scale = scale,
						collected = false
					})
				end
			end
		end
	end

	-- Arcade: inicjalizacja w arcade.lua
	arcade:load(world, gameMap)
	print("Loaded arcade objects:", #arcade.objects)
	
	
	minimap = require("maps.minimap")
	bars = require("playerstuff.bars")
	pickup = require("playerstuff.pickupitemy")

	player = require("playerstuff.player")
	player:load(world, anim8)

	
    -- 1. Załadowuje początkowy chunk, aby ściany istniały w buforze
    dungeon.getChunk(0, 0)

    -- 2. Pobierz WSZYSTKIE kolidery ścian, które zostały utworzone przez dungeon
    -- (walls będzie zawierać listę obiektów {x, y, w, h, collider})
    walls = dungeon.getAllWalls()
    
    -- 3. Przekazuje tę listę do systemu pocisków.
    bullets:setWalls(walls)

	debugMode = false
	print("Game loaded with state:", gameState)

	-- Załadowuje początkowy chunk żeby nie było pustego świata na start
	dungeon.getChunk(0, 0)
	-- Ustawia pozycję gracza na środku pierwszego chunka (jeśli collider istnieje)
	if player and player.collider and player.collider.setPosition then
		player.collider:setPosition(32 * 64 / 2, 32 * 64 / 2)
	end
end

function drawTile(tile, x, y)
    -- 0 = ściana, 384 = podłoga)
    if tile == 0 then
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", x, y, 64, 64)
    elseif tile == 384 then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.rectangle("fill", x, y, 64, 64)
    end

    love.graphics.setColor(1,1,1)
end

function love.update(dt)
	if gameState == "menu" then return end

	if gameState == "playing" then
		world:update(dt)

		if not inventory.isOpen then
			player:update(dt)
			arcade:update(dt, player)
		else
			player.collider:setLinearVelocity(0, 0)
		end

		cam:lookAt(player.x, player.y)

		local w, h = love.graphics.getWidth(), love.graphics.getHeight()
		local mapW, mapH = gameMap.width * gameMap.tilewidth, gameMap.height * gameMap.tileheight
		if cam.x < w / 2 then cam.x = w / 2 end
		if cam.y < h / 2 then cam.y = h / 2 end
		if cam.x > (mapW - w / 2) then cam.x = (mapW - w / 2) end
		if cam.y > (mapH - h / 2) then cam.y = (mapH - h / 2) end

		pickup.update(player, inventory, inventory.itemsOnMap, itemsData)
	elseif gameState == "snake" then
		snake:update(dt)
	end

	bullets:update(dt)
	enemies:update(dt)


	dungeon.update(player.x, player.y)
	bullets:setWalls(dungeon.getAllWalls())
end

function love.draw()
	if gameState == "menu" then
		menu.draw()
		return
	end

	if gameState == "playing" then
		cam:attach()
			-- zamiast rysowania starego STI layerów używamy chunkowego renderer'a
			-- drawTile jest zdefiniowane powyżej i przekażemy pozycję gracza do rysowania
			dungeon.draw(drawTile, player.x, player.y)

			arcade:draw(debugMode)
			player:draw()
			bullets:draw() -- Rysowanie pocisków
			enemies:draw() -- rysowanie dummy
			

			for _, item in ipairs(inventory.itemsOnMap) do
				if not item.collected and item.data and item.data.image then
					local scale = item.scale or 1
					love.graphics.draw(item.data.image, item.x, item.y, 0, scale, scale)
				end
			end
		cam:detach()

		minimap.draw(gameMap, player)
		bars:draw(player)
		leveling:draw()

		if inventory.isOpen then
			love.graphics.setColor(0, 0, 0, 0.5)
			love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
			love.graphics.setColor(1, 1, 1)
		end

		inventory:draw()
	elseif gameState == "snake" then
		snake:draw()
	end

	-- DEBUG MENU
	if debugMode then
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
    		for _, chunkY in pairs(dungeon.colliders) do
        		for _, wallsList in pairs(chunkY) do
            		totalWalls = totalWalls + #wallsList
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
end

function love.textinput(t)
	menu:textinput(t)
end

function love.keypressed(key)
	if key == "f3" then
		debugMode = not debugMode
		return
	end

	if gameState == "menu" then
		local action = menu:keypressed(key)
		if action == "start" and menu.nameEntered then
			gameState = "playing"
			player.name = menu.playerNameInput
		elseif action == "quit" then
			love.event.quit()
		end
	elseif gameState == "playing" then

		-- leveling kontrolki
		if leveling.levelUpAvailable then
            leveling:keypressed(key)
            return
        end

		local mappedKey = MapKey(key) 

		if inventory.isOpen then
			if mappedKey == "inventory" or key == "e" then
				inventory:toggle()
			else
				inventory:keypressed(key)
			end
			return
		end

		player:keypressed(key)

		if mappedKey == "inventory" or key == "e" then
			inventory:toggle()
		elseif key == "escape" then
			gameState = "menu"
		end

		if key == "return" then
			if arcade:interact(player) then
				print("Player pressed Enter near arcade!")
				snake:load()
				gameState = "snake"
			end
		end

	elseif gameState == "snake" then
		snake:keypressed(key)
		if key == "escape" then
			gameState = "playing"
		end
	end
end

function love.mousepressed(x, y, button)
	if leveling.mousepressed(x, y, button) then return end
	player:mousepressed(x, y, button)

	if gameState == "menu" then
		local action = menu:mousepressed(x, y, button)
		if action == "start" and menu.nameEntered then
			gameState = "playing"
			player.name = menu.playerNameInput
		elseif action == "quit" then
			love.event.quit()
		end
	end
end
