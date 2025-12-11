-- biblioteki
local wf = require "libraries/windfield"
local camera = require "libraries/camera"
local anim8 = require "libraries/anim8"
local sti = require "libraries/sti"

-- Wstępne ładowanie kontrolek
local controls = require("controls")

-- Obiekt stanu gry
local Game = {}
Game.controls = controls 

-- Globalne zmienne gry
world = nil
cam = nil

-- Globalne shimy dla MapKey/GetBoundKey
function MapKey(key) 
	if Game.controls and Game.controls.MapKey then
		return Game.controls.MapKey(key) 
	end
	return key
end
function GetBoundKey(actionName) 
	if Game.controls and Game.controls.GetBoundKey then
		return Game.controls.GetBoundKey(actionName) 
	end
	return actionName
end
_G.MapKey = MapKey
_G.GetBoundKey = GetBoundKey


-- ŁADOWANIE MODUŁÓW GRY
local utf8 = require("utf8")
local arcade = require("minigry.arcade")
local snake = require("minigry.snake")
local dungeon = require("maps.dungeon")

bullets = require("combat.bullets") 	_G.bullets = bullets
enemies = require("combat.enemieslogic") 	_G.enemies = enemies

local EnemyDefinitions = require("combat.enemieslist")

-- UWAGA: Jeśli plik na dysku to SlimeRenderer.lua, Zmień tę linię na:
local yetAnotherEnemies = require("combat.slimerenderer")

player = require("playerstuff.player") _G.player = player
local leveling = require("playerstuff.leveling")
local EnemySpawn = require("combat.enemyspawn")
local debugMenu = require("debugmenu")
local mapItems = require("maps.mapitems")
local quickslots = require("playerstuff.quickslots")

inventory = require("playerstuff.inventory") _G.inventory = inventory
local itemsData = require("playerstuff.items")
local minimap = require("maps.minimap")
local bars = require("playerstuff.bars")
local pickup = require("playerstuff.pickupitemy")
local menu = require("menu")

-- === NOWO DODANY MODUŁ PRZYCISKÓW HUD ===
local buttonsUI = require("buttons") 
_G.buttonsUI = buttonsUI -- Globalna referencja dla kontrolera
------------------------------------------

-- Ustawienie domyślnej skali (dla diagnostyki, zakładając, że używasz 1920 jako bazy)
_G.scale = 1.0 
_G.buttonsUI = buttonsUI -- Upewnienie się, że jest globalnie dostępne


function love.load()
	-- Inicjalizacja obiektu gry

	_G.Game = Game
	Game.map = { layers = {}, width = 1024, height = 1024, tilewidth = 64, tileheight = 64 }
	
	world = wf.newWorld(0, 0) 
	_G.world = world
	Game.world = world
	
	cam = camera() 
	_G.cam = cam
	Game.cam = cam
	
	love.graphics.setDefaultFilter("nearest", "nearest")

	-- === SEKCJA DIAGNOSTYCZNA CZCIONEK ===
	-- Zakładając, że czcionki są ładowane po wczytaniu modułów:
	Game.fonts = {}
	local defaultFontSize = 18
	Game.fonts.default = love.graphics.newFont(defaultFontSize)
	love.graphics.setFont(Game.fonts.default)

	print("MAIN.LUA LOAD (DIAG): Ustawiono domyślną czcionkę o rozmiarze " .. tostring(defaultFontSize))
	-- Wstępnie ustawiamy skalę globalną (jeśli nie jest używana, będzie 1.0)
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	_G.scale = w / 1920 
	print("MAIN.LUA LOAD (DIAG): Global Scale (_G.scale) = " .. tostring(_G.scale))
	-- ======================================


	dungeon.setPhysicsWorld(world)

	world:addCollisionClass('Player')
	world:addCollisionClass('Enemy')
	world:addCollisionClass('Bullet')
	world:addCollisionClass('Wall')

	-- Przypisanie do obiektu Game
	Game.bullets = bullets
	Game.enemies = enemies
	Game.player = player
	Game.inventory = inventory
	Game.itemsData = itemsData
	Game.menu = menu
	Game.leveling = leveling
	Game.quickslots = quickslots
	Game.arcade = arcade
	Game.snake = snake
	Game.minimap = minimap
	Game.bars = bars
	Game.pickup = pickup

	-- Inicjalizacje modułów
	bullets:init(world, enemies, player)
	bullets:load()
	enemies:init(world)

	EnemySpawn.spawnInitialWave(enemies, EnemyDefinitions)

	menu:init(Game) -- Przekazujemy Game do init menu
	Game.state = "menu"
	Game.debugMode = false
	
	controls.init(menu)

	-- === INICJALIZACJA PRZYCISKÓW HUD ===
	buttonsUI:load() 
	--------------------------------------

	-- ZMIANA A: Wymuszamy odświeżenie pozycji HUD po załadowaniu
	if Game.bars and Game.bars.recalculatePosition then
		Game.bars:recalculatePosition()
		print("MAIN.LUA LOAD (DIAG): Wymuszenie bars:recalculatePosition.")
	end
	
	-- POPRAWKA: Zabezpieczenie przed błędem 'attempt to index field 'minimap' (a number value)'
	if type(Game.minimap) == 'table' and Game.minimap.recalculatePosition then
		Game.minimap:recalculatePosition(Game.map) -- DODANIE ARGUMENTU Game.map
		print("MAIN.LUA LOAD (DIAG): Wymuszenie minimap:recalculatePosition.")
	end
	
	-- Inventory
	inventory:init()
	itemsData:loadImages()
	inventory.items = {}

	local startingItems = { "BUZZGAREN", "StaminaRing", "helmet", "chestplate", "leggins", "boots", "Shotgun", "AssaultRifle" }
	for i, itemName in ipairs(startingItems) do
		local item = { itemType = itemName, data = itemsData[itemName], equipped = false, amount = 1 }
		inventory.items[i] = item
		
		if itemName == "Shotgun" then
			inventory:equipItem(item)
		end
	end

	-- Quickslots
	quickslots:setDependencies(inventory)
	quickslots:init()

	mapItems.init(Game.map, inventory, itemsData)
	leveling:init(player)

	-- Player Setup
	player:load(world, anim8)
	
	-- Ustawiamy domyślny nick, dopóki gracz go nie ustawi w menu
	if not Game.player.name then
		Game.player.name = "NO NAME" 
	end


	-- Ustawianie ścian dla pocisków
	dungeon.getChunk(0, 0)
	walls = dungeon.getAllWalls()
	bullets:setWalls(walls)

	print("Game loaded with state:", Game.state)

	if player and player.collider and player.collider.setPosition then
		player.collider:setPosition(32 * 64 / 2, 32 * 64 / 2)
	end
end

function drawTile(tile, x, y)
	if tile == 0 then
		love.graphics.setColor(0.1, 0.1, 0.1)
		love.graphics.rectangle("fill", x, y, 64, 64)
	elseif tile == 384 then
		love.graphics.setColor(0.6, 0.6, 0.6)
		love.graphics.rectangle("fill", x, y, 64, 64)
	end
	love.graphics.setColor(1,1,1)
end

-- === DODANA FUNKCJA OBSŁUGI ZMIANY ROZMIARU OKNA ===
function love.resize(w, h)
	-- AKTUALIZACJA GLOBALNEJ SKALI
	_G.scale = w / 1920 
	print("MAIN.LUA RESIZE (DIAG): Odświeżono globalną skalę: " .. tostring(_G.scale))
	
	-- Aktualizacja pozycji inwentarza przy zmianie rozmiaru okna
	if Game and Game.inventory and Game.inventory.recalculatePosition then
		Game.inventory:recalculatePosition()
		print("MAIN.LUA RESIZE (DIAG): Wymuszenie inventory:recalculatePosition.")
	end
	
	-- Aktualizujemy przyciski kontrolera przy zmianie rozmiaru okna
	if Game.controls and Game.controls.refreshControls then
		Game.controls:refreshControls()
	end
	
	-- ZMIANA B: ODŚWIEŻENIE ELEMENTÓW HUD
	if Game.bars and Game.bars.recalculatePosition then
		Game.bars:recalculatePosition()
	end
	
	-- POPRAWKA: Zabezpieczenie przed błędem 'attempt to index field 'minimap' (a number value)'
	if type(Game.minimap) == 'table' and Game.minimap.recalculatePosition then
		Game.minimap:recalculatePosition(Game.map) -- DODANIE ARGUMENTU Game.map
	end
end



function love.update(dt)
	-- Jeśli jesteśmy w menu lub wprowadzamy nick, nie aktualizujemy świata gry
	if Game.state == "menu" or Game.state == "nick_input" then return end

	if Game.state == "playing" then
		world:update(dt)

		if not Game.inventory.isOpen then
			Game.player:update(dt)
			Game.arcade:update(dt, Game.player)
		else
			Game.player.collider:setLinearVelocity(0, 0)
		end

		cam:lookAt(Game.player.x, Game.player.y)

		local w, h = love.graphics.getWidth(), love.graphics.getHeight()
		local mapW, mapH = Game.map.width * Game.map.tilewidth, Game.map.height * Game.map.tileheight
		if cam.x < w / 2 then cam.x = w / 2 end
		if cam.y < h / 2 then cam.y = h / 2 end
		if cam.x > (mapW - w / 2) then cam.x = (mapW - w / 2) end
		if cam.y > (mapH - h / 2) then cam.y = (mapH - h / 2) end

		Game.pickup.update(Game.player, Game.inventory, Game.inventory.itemsOnMap, Game.itemsData)
	elseif Game.state == "snake" then
		Game.snake:update(dt)
	end

	bullets:update(dt)
	enemies:update(dt)

	dungeon.update(Game.player.x, Game.player.y)
	bullets:setWalls(dungeon.getAllWalls())
end

function love.draw()
	-- Jeśli jesteśmy w menu LUB wprowadzamy nick, rysujemy tylko menu
	if Game.state == "menu" or Game.state == "nick_input" then
		Game.menu.draw(Game) -- Przekazujemy Game
		return
	end

	if Game.state == "playing" then
		cam:attach()
			dungeon.draw(drawTile, Game.player.x, Game.player.y)

			Game.arcade:draw(Game.debugMode)
			
			mapItems.draw(Game.inventory)
			
			Game.player:draw()
			bullets:draw()
			enemies:draw()
		cam:detach()

		Game.minimap.draw(Game.map, Game.player)
		Game.bars:draw(Game.player)
		Game.leveling:draw()

		Game.quickslots:draw()

		if Game.inventory.isOpen then
			love.graphics.setColor(0, 0, 0, 0.5)
			love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
			love.graphics.setColor(1, 1, 1)
		end

		Game.inventory:draw()
		
		-- === RYSOWANIE PRZYCISKÓW HUD (OPCJE/EKWIPUNEK) ===
		buttonsUI:draw(Game)
		-----------------------------------------------------

		-- LOGIKA RYSOWANIA KONTROLEK DOTYKOWYCH
		local os = love.system.getOS()
		if Game.controls.draw and (os == "Android" or os == "iOS") then
			Game.controls.draw(Game)
		end
		
	elseif Game.state == "snake" then
		Game.snake:draw()
	end

	if Game.debugMode then
		debugMenu.draw(Game.player, cam, world, dungeon, Game.inventory, Game.arcade)
	end
end

-- PRZEKIEROWANIA WEJŚCIA DLA KONTROLEK

function love.textinput(t)
	controls.textinput(t, Game)
end

function love.keypressed(key)
	controls.keypressed(key, Game)
end

function love.mousepressed(x, y, button)
	controls.mousepressed(x, y, button, Game)
end

-- *** DODANE ZDARZENIE ***
function love.mousereleased(x, y, button)
	controls.mousereleased(x, y, button, Game)
end
--------------------------

function love.wheelmoved(x, y)
	controls.wheelmoved(x, y, Game)
end

function love.mousemoved(x, y, dx, dy, istouch)
    inventory:mousemoved(x, y, dx, dy, istouch)
end

-- ANDROID / IOS TOUCH INPUT HANDLING

function love.touchpressed(id, x, y, pressure)
	controls.touchpressed(id, x, y, pressure, Game)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
	controls.touchmoved(id, x, y, dx, dy, pressure, Game)
end

function love.touchreleased(id, x, y, pressure)
	controls.touchreleased(id, x, y, pressure, Game)
end