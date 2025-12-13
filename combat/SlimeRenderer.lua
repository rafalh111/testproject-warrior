-- File: SlimeRenderer.lua

local SlimeRenderer = {}
local loadedResources = {} -- Przechowuje załadowane obrazy, quady i dane dla każdego spritePath

-- Inicjalizacja: Wymagana do przechowywania Definicji
function SlimeRenderer.init(EnemyDefinitions)
	SlimeRenderer.EnemyDefs = EnemyDefinitions
end

-- Ładowanie zasobów Slime'ów
function SlimeRenderer.load()
	local EnemyDefinitions = SlimeRenderer.EnemyDefs or require("combat.enemieslist")
	
	-- Iteracja po wszystkich definicjach, aby załadować unikalne sprite'y
	for id, def in pairs(EnemyDefinitions.list) do
		-- Sprawdzamy, czy definicja jest typu Slime i ma dane renderowania
		if def.renderKey == "SLIME_RENDER" and def.renderData then
			local path = def.renderData.spritePath
			
			if not loadedResources[path] then
				
				-- Ładowanie obrazu
				local image = love.graphics.newImage(path)
				local quads = {}
				
				-- Tworzenie Quadów do animacji
				for i = 0, def.renderData.maxFrames - 1 do
					table.insert(quads, love.graphics.newQuad(
						i * def.renderData.frameWidth, 
						0, 
						def.renderData.frameWidth, 
						def.renderData.frameHeight, 
						image:getDimensions()
					))
				end
				
				-- Zapisanie zasobów
				loadedResources[path] = {
					image = image,
					quads = quads,
					data = def.renderData -- Zapisujemy definicję klatek/skali
				}
			end
		end
	end
end

-- Aktualizacja animacji
function SlimeRenderer.updateSlimeAnimation(slime, dt)
	local def = slime.renderData or SlimeRenderer.EnemyDefs.list[slime.id].renderData 

	slime.animationTimer = slime.animationTimer + dt
	
	if slime.animationTimer >= def.animationSpeed then
		slime.animationTimer = slime.animationTimer - def.animationSpeed
		slime.currentFrame = (slime.currentFrame % def.maxFrames) + 1
	end
end


-- Rysowanie Slime'a
function SlimeRenderer.drawSlime(slime)
	-- Pobieranie zasobów i danych
	local path = slime.renderData.spritePath
	local res = loadedResources[path]
	
	if not res or not res.quads[slime.currentFrame] then return end
	
	local def = res.data 
	local currentQuad = res.quads[slime.currentFrame]
	
	local r, g, b = 1, 1, 1 -- Domyślny kolor: Biały (bez tintowania)

	-- LOGIKA CYKLU KOLORÓW DLA BOSSA
	if def.colorCycleActive then
		local list = def.colorCycleList
		local speed = def.colorCycleSpeed
		local numColors = #list
		
		local time = love.timer.getTime()
		
		-- Obliczenia indeksów i współczynnika mieszania
		local currentCycleTime = time / speed 
		local indexFloat = currentCycleTime % numColors
		
		local index1 = math.floor(indexFloat) + 1 
		local index2 = (index1 % numColors) + 1 
		
		local t = indexFloat - math.floor(indexFloat)
		
		local c1 = list[index1]
		local c2 = list[index2]

		-- Interpolacja liniowa (mieszanie kolorów)
		r = c1[1] * (1 - t) + c2[1] * t
		g = c1[2] * (1 - t) + c2[2] * t
		b = c1[3] * (1 - t) + c2[3] * t
	end

	-- Ustawienie koloru (tintowanie) PRZED rysowaniem sprite'a
	love.graphics.setColor(r, g, b) 

	
	-- Korekta przesunięcia (Centrowanie animacji)
	local displayW = def.frameWidth * slime.scale
	local displayH = def.frameHeight * slime.scale
	local offsetX = (displayW - slime.w) / 2 
	local offsetY = (displayH - slime.h) / 2 
	
	-- Rysowanie animacji
	love.graphics.draw(
		res.image, 
		currentQuad, 
		slime.x - offsetX, 
		slime.y - offsetY, 
		0, 
		slime.scale, 
		slime.scale
	)

	-- Ważne: Resetowanie koloru na biały po narysowaniu sprite'a
	love.graphics.setColor(1, 1, 1) 

	-- RYSOWANIE PASKA HP
	local hpPerc = slime.hp / slime.maxHp
	
	if hpPerc < 1 then 
		local hpBarWidth = slime.w 
		local hpBarHeight = 5
		local hpBarY = slime.y - 10
		
		love.graphics.setColor(0.1, 0.1, 0.1, 0.8) -- Tło paska HP
		love.graphics.rectangle("fill", slime.x, hpBarY, hpBarWidth, hpBarHeight)
		
		love.graphics.setColor({0, 0.8, 0.2}) -- Kolor paska (Zielony)
		
		love.graphics.rectangle("fill", slime.x, hpBarY, hpBarWidth * hpPerc, hpBarHeight)
	end
	
	-- Zresetowanie koloru po rysowaniu paska HP
	love.graphics.setColor(1, 1, 1) 

end

return SlimeRenderer