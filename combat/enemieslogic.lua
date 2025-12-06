local EnemiesLogic = {}
local player = require("playerstuff.player")
local EnemyDefinitions = require("combat.enemieslist")
local enemyRenderers = {}
local leveling = require("playerstuff.leveling")


function EnemiesLogic:init(world)
    self.world = world
    self.list = {}
    self.damageTexts = {}
    
    -- Ładowanie rendererów
    -- POPRAWKA: Przekazujemy listę definicji do renderera, aby mógł załadować wszystkie sprite'y.
    enemyRenderers.SLIME_RENDER = require("combat.yetanotherenemies") -- Zakładam, że yetanotherenemies to teraz SlimeRenderer

	-- Inicjalizacja rendererów
		for _, renderer in pairs(enemyRenderers) do
    	-- DODAJ TO: Przekaż EnemyDefinitions do init()
    		if renderer.init then renderer.init(EnemyDefinitions) end 
    		if renderer.load then renderer.load() end
		end
	end

-- Funkcja pomocnicza do tworzenia dowolnego wroga
local function createEnemy(self, typeId, x, y, w, h)
	local def = EnemyDefinitions.list[typeId] 
	if not def then
		print("Error: Unknown enemy type ID: " .. typeId)
		return
	end

	local width = w or def.width
	local height = h or def.height
	local centerX = x + width / 2
	local centerY = y + height / 2
	
	local enemy = {
		id = typeId,
		x = x,
		y = y,
		w = width,
		h = height,
		hp = def.maxHp,
		maxHp = def.maxHp,
		type = def.name,
		color = def.color,
		damageTakenThisFrame = 0,
		dmgTextOffsetY = def.dmgTextOffsetY,
		isDead = false,
		
		-- Windfield
		collider = self.world:newRectangleCollider(centerX, centerY, width, height)
	}

	enemy.collider:setType(def.isStatic and "static" or "dynamic")
	enemy.collider:setCollisionClass("Enemy")
	enemy.collider.parent = enemy 
	
	-- Skala slime'a itd xd
    if def.renderKey == "SLIME_RENDER" then
    enemy.currentFrame = 1
    enemy.animationTimer = 0

    -- POPRAWKA: Pobieramy skalę z definicji
    enemy.scale = def.renderData and def.renderData.defaultScale or 4.0

    -- POPRAWKA: Zapisujemy renderData (KRYTYCZNE)
    enemy.renderData = def.renderData 
end

    table.insert(self.list, enemy)
    return enemy
end

-- Funkcja do spawnowania "Dummy"
function EnemiesLogic:spawnDummy(x, y, w, h)
	return createEnemy(self, EnemyDefinitions.DUMMY_ID, x, y, w, h)
end

-- Funkcja do spawnowania "BigDummy"
function EnemiesLogic:spawnBigDummy(x, y, w, h)
	return createEnemy(self, EnemyDefinitions.BIGDUMMY_ID, x, y, w, h)
end

-- Funkcja do spawnowania dowolnego wroga
function EnemiesLogic:spawnEnemy(typeId, x, y, w, h)
	return createEnemy(self, typeId, x, y, w, h)
end


-- Sumowanie dmg
function EnemiesLogic:takeDamage(enemy)
    local dmg = player.damage or 1 

    enemy.hp = enemy.hp - dmg 
    enemy.damageTakenThisFrame = enemy.damageTakenThisFrame + dmg 
    
    if enemy.hp <= 0 then
        local def = EnemyDefinitions.list[enemy.id]
        
        -- Wszyscy wrogowie, którzy NIE są statyczni (isStatic == false), powinni umierać
        if not def.isStatic then
             enemy.hp = 0
             enemy.isDead = true
        else
            -- Dummy/BigDummy są statyczne (isStatic == true) i regenerują się
            enemy.hp = enemy.maxHp
        end
    end
end

function EnemiesLogic:update(dt)
	-- Pętla od końca
	for i = #self.list, 1, -1 do
		local e = self.list[i]
		
		-- Sprawdzenie, czy wróg jest martwy, i jego usunięcie
		if e.isDead then
            -- DODANIE XP
            if e.id == EnemyDefinitions.SLIME_ID then -- Sprawdzamy, czy to Slime (lub inny wróg dający XP)
                leveling:addXP(e.id)
            end
			    if e.collider then
				e.collider:destroy()
			end
			-- Usuwamy wroga z listy
			table.remove(self.list, i)
			goto continue
		end
		
		-- Logika ruchu Slime'a (jeśli dynamiczny)
		if not EnemyDefinitions.list[e.id].isStatic then
			-- ZABEZPIECZENIE: Aktualizacja pozycji tylko jeśli kolider istnieje
			if e.collider then
				local centerX, centerY = e.collider:getPosition() -- Pozycja kolidera to środek
				
				-- Aktualizacja pozycji e.x i e.y (lewy górny róg)
				e.x = centerX - e.w / 2
				e.y = centerY - e.h / 2
			end
		end
		
		-- Renderowanie i animacja Slime'a
		if EnemyDefinitions.list[e.id].renderKey == "SLIME_RENDER" then
			enemyRenderers.SLIME_RENDER.updateSlimeAnimation(e, dt)
		end
		
		if e.damageTakenThisFrame > 0 then
			table.insert(self.damageTexts, {
				x = e.x + e.w / 2,
				y = e.y - e.dmgTextOffsetY, 
				dmg = math.floor(e.damageTakenThisFrame),
				timer = 0.5,
				vy = -30,
				color = e.color or {1, 1, 0}
			})
			e.damageTakenThisFrame = 0 
		end
		
		::continue::
	end

	-- update floating damage texts (bez zmian)
	for i = #self.damageTexts, 1, -1 do
		local t = self.damageTexts[i]
		t.y = t.y + t.vy * dt
		t.timer = t.timer - dt
		if t.timer <= 0 then
			table.remove(self.damageTexts, i)
		end
	end
end

function EnemiesLogic:draw()
	for _, e in ipairs(self.list) do
		local def = EnemyDefinitions.list[e.id]
		
		-- Rysowanie rendererem (jeśli ma renderKey)
		if def.renderKey == "DUMMY_RENDER" then
			-- Rysowanie Dummy
			local hpPerc = e.hp / e.maxHp
			local hpBarWidth = e.w 
			local hpBarHeight = 5
			local hpBarY = e.y - 10

			love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
			love.graphics.rectangle("fill", e.x, hpBarY, hpBarWidth, hpBarHeight)
			love.graphics.setColor(e.color or {0, 1, 0}) 
			love.graphics.rectangle("fill", e.x, hpBarY, hpBarWidth * hpPerc, hpBarHeight)
			love.graphics.setColor(1, 1, 1, 0.2)
			love.graphics.rectangle("line", e.x, e.y, e.w, e.h)
		elseif def.renderKey == "SLIME_RENDER" then
			-- Delegowanie rysowania do yetanotherenemies
			enemyRenderers.SLIME_RENDER.drawSlime(e)
		end
	end

	-- Rysowanie floating damage text
	for _, t in ipairs(self.damageTexts) do
		love.graphics.setColor(t.color or {1, 1, 0}) 
		love.graphics.printf(tostring(math.floor(t.dmg)), t.x - 50, t.y, 100, "center") 
	end
	love.graphics.setColor(1, 1, 1) 
end

-- Udostępnienie listy tekstów obrażeń
function EnemiesLogic.getDamageTexts()
	return EnemiesLogic.damageTexts
end


return EnemiesLogic