-- main.lua

-- biblioteki
local wf = require "libraries/windfield"
local camera = require "libraries/camera"
local anim8 = require "libraries/anim8"
local sti = require "libraries/sti"

-- moduły gry
local utf8 = require("utf8")
local arcade = require("minigry.arcade")
local snake = require("minigry.snake")
local dungeon = require("maps.dungeon")
local bullets = require("combat.bullets")
local enemies = require("combat.enemieslogic")
local EnemyDefinitions = require("combat.enemieslist")
local yetAnotherEnemies = require("combat.SlimeRenderer")
local player = require("playerstuff.player")
local leveling = require("playerstuff.leveling")
local EnemySpawn = require("combat.enemyspawn")
local debugMenu = require("debugmenu")
local mapItems = require("maps.mapitems")
local quickslots = require("playerstuff.quickslots")

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

	-- MODYFIKACJA: Dodano logikę wyposażania startowego Shotguna
	local startingItems = { "BUZZGAREN", "StaminaRing", "helmet", "chestplate", "leggins", "boots", "Shotgun", "AssaultRifle" }
	for i, itemName in ipairs(startingItems) do
		local item = { itemType = itemName, data = itemsData[itemName], equipped = false, amount = 1 }
		inventory.items[i] = item
		
		-- Wyposażamy Shotguna, aby od razu pojawił się w Quickslocie 1
		if itemName == "Shotgun" then
			inventory:equipItem(item)
		end
	end

	-- Quickslots - DODANE INICJALIZACJA
	quickslots:setDependencies(inventory)
	quickslots:init()

	-- Inicjalizacja przedmiotów na mapie (ze sztywno zdefiniowanych pozycji)
	mapItems.init(gameMap, inventory, itemsData) 

	leveling:init(player)

	minimap = require("maps.minimap")
	bars = require("playerstuff.bars")
	pickup = require("playerstuff.pickupitemy")

	player = require("playerstuff.player")
	player:load(world, anim8)

	-- 1. Załadowuje początkowy chunk, aby ściany istniały w buforze
	dungeon.getChunk(0, 0)

	-- 2. Pobierz WSZYSTKIE kolidery ścian, które zostały utworzone przez dungeon
	walls = dungeon.getAllWalls()
	
	-- 3. Przekazuje tę listę do systemu pocisków.
	bullets:setWalls(walls)

	debugMode = false
	print("Game loaded with state:", gameState)

	-- Ustawia pozycję gracza na środku pierwszego chunka (jeśli collider istnieje)
	dungeon.getChunk(0, 0)
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

		-- Aktualizacja logiki zbierania przedmiotów na mapie
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
			-- Rysowanie mapy generowanej proceduralnie
			dungeon.draw(drawTile, player.x, player.y)

			arcade:draw(debugMode)
			
			-- Rysowanie przedmiotów leżących na mapie (pod graczem)
			mapItems.draw(inventory) 
			
			player:draw()
			bullets:draw()
			enemies:draw()
		cam:detach()

		minimap.draw(gameMap, player)
		bars:draw(player)
		leveling:draw()

		-- Rysowanie Quickslots - DODANE
		quickslots:draw()

		if inventory.isOpen then
			-- Przyciemnienie ekranu podczas otwarcia inventory
			love.graphics.setColor(0, 0, 0, 0.5)
			love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
			love.graphics.setColor(1, 1, 1)
		end

		inventory:draw()
	elseif gameState == "snake" then
		snake:draw()
	end

	-- SEKCJA DEBUG
	if debugMode then
		-- Rysowanie menu debugowania z zewnętrznego modułu
		debugMenu.draw(player, cam, world, dungeon, inventory, arcade)
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

		-- leveling kontrolki (priorytet)
		if leveling.levelUpAvailable then
			leveling:keypressed(key)
			return
		end

		local mappedKey = MapKey(key) 

		-- Obsługa inventory
		if inventory.isOpen then
			if mappedKey == "inventory" or key == "e" then
				inventory:toggle()
			else
				inventory:keypressed(key)
			end
			return
		end

		-- QUICKSLOTS KONTROLA NUMERYCZNA - DODANE
		if key == "1" then
			quickslots.currentSlot = 1
			quickslots:useCurrentSlot()
			return
		elseif key == "2" then
			quickslots.currentSlot = 2
			quickslots:useCurrentSlot()
			return
		elseif key == "3" then
			quickslots.currentSlot = 3
			quickslots:useCurrentSlot()
			return
		end
		-- KONIEC QUICKSLOTS KONTROLA NUMERYCZNA

		player:keypressed(key)

		if mappedKey == "inventory" or key == "e" then
			inventory:toggle()
		elseif key == "escape" then
			gameState = "menu"
		end

		-- Interakcja z automatem arcade
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

-- OBSŁUGA SCROLLA MYSI DLA QUICKSLOTS - DODANE
function love.wheelmoved(x, y)
	-- Sprawdzamy, czy jesteśmy w grze i inwentarz jest zamknięty
	if gameState == "playing" and not inventory.isOpen then
		local delta = 0
		if y > 0 then
			delta = -1 -- Scroll w górę (poprzedni slot)
		elseif y < 0 then
			delta = 1 -- Scroll w dół (następny slot)
		end
		
		if delta ~= 0 then
			quickslots:changeSlot(delta)
		end
	end
end