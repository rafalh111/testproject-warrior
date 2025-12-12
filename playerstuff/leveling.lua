local Leveling = {}
local math = math or {}
local love = love or {}
local player = nil 

-- ============================================================
-- KONFIGURACJA GRY I PROGRESJI
-- ============================================================
local ENEMY_XP_VALUE = 2 
local BASE_WINDOW_WIDTH = 300 -- Zmniejszony rozmiar
local BASE_WINDOW_HEIGHT = 400 -- Zmniejszony rozmiar
local BASE_SCREEN_W = 800 -- Wartość referencyjna dla skalowania (np. 800px)

-- -- -- STAN POZIOMOWANIA -- -- --
Leveling.currentLevel = 0
Leveling.currentXP = 0
Leveling.XPToNextLevel = 2 
Leveling.levelCap = 100
Leveling.levelUpAvailable = false 
Leveling.attributePoints = 0 
Leveling.selectedAttribute = 1 

-- -- -- Okno ulepszeń (Dynamiczne) -- -- --
Leveling.window = {
	width = BASE_WINDOW_WIDTH,
	height = BASE_WINDOW_HEIGHT,
	scale = 1.0 -- Zmienna do przechowywania skalowania
}

Leveling.attributes = {
	"HP", "STR", "MANA", "STAMINA", "SPEED"
}

-- Definicja wzmocnień na 1 punkt
Leveling.upgradeStats = {
	HP = { baseKey = "baseMaxHp", value = 5, name = "Max HP (+5% Bazowej)" },
	STR = { baseKey = "baseDamage", value = 5, name = "Damage (+5% Bazowej)" },
	MANA = { baseKey = "baseMaxMana", value = 5, name = "Max Mana (+5% Bazowej)" },
	STAMINA = { baseKey = "baseMaxStamina", value = 5, name = "Max Stamina (+5% Bazowej)" },
	SPEED = { baseKey = "baseSpeed", value = 1, name = "Movement Speed (+1% Bazowej)" },
}


-- -- -- FUNKCJE POMOCNICZE -- -- --

-- Oblicza XP potrzebne na następny poziom
local function calculateXP(level)
	if level >= Leveling.levelCap then return math.huge end
	return 2 ^ level
end

-- Aktualizuje statystyki gracza (poziomy % i płaskie) po wydaniu punktu.
function Leveling:recalculateStats(attributeKey)
	local upgrade = Leveling.upgradeStats[attributeKey]
	if not upgrade then return end
	
	local pointsKey = upgrade.baseKey .. "Points"
	local points = player[pointsKey] or 0
	local baseKey = upgrade.baseKey

	-- 1. Obliczanie statystyk
	local base = player[baseKey]
	-- Wartość bazowa + (Wartość bazowa * Punkty / 100)
	local newValue = base + (base * (points / 100)) 
	-- Korekta dla SPEED, gdzie value to płaski bonus 
	if attributeKey == "SPEED" then
		newValue = base + points
	end

	-- 2. Aktualizacja i uzupełnianie (tylko dla HP i MANA)
	if attributeKey == "HP" then
		local diff = newValue - (player.maxHp or base) 
		player.maxHp = newValue
		player.hp = (player.hp or player.maxHp) + diff 
	elseif attributeKey == "MANA" then
		local diff = newValue - (player.maxMana or base) 
		player.maxMana = newValue
		player.mana = (player.mana or player.maxMana) + diff 
	elseif attributeKey == "STR" then
		player.damage = newValue
	elseif attributeKey == "STAMINA" then
		player.maxStamina = newValue
	elseif attributeKey == "SPEED" then
		player.speed = newValue
	end
end


-- Wymaga, aby player został przekazany z main.lua
function Leveling:init(playerRef)
	player = playerRef
	
	-- Inicjalizacja pól bazowych (wartości domyślne)
	player.baseMaxHp = player.baseMaxHp or 100
	player.baseMaxMana = player.baseMaxMana or 100
	player.baseSpeed = player.baseSpeed or 300
	player.baseDamage = player.baseDamage or 5 
	player.baseMaxStamina = player.baseMaxStamina or 100
	
	-- Inicjalizacja pól do śledzenia punktów atrybutów
	local function initPoints(baseKey)
		player[baseKey .. "Points"] = player[baseKey .. "Points"] or 0
	end
	initPoints("baseMaxHp"); initPoints("baseMaxMana"); initPoints("baseDamage")
	initPoints("baseMaxStamina"); initPoints("baseSpeed")

	-- Inicjalizacja aktualnych statystyk
	player.maxHp = player.maxHp or player.baseMaxHp
	player.hp = player.hp or player.maxHp
	player.maxMana = player.maxMana or player.baseMaxMana
	player.mana = player.mana or player.baseMaxMana
	player.damage = player.damage or player.baseDamage
	player.speed = player.speed or player.baseSpeed
	player.maxStamina = player.maxStamina or player.baseMaxStamina
	
	player.currentLevel = player.currentLevel or 1
	player.currentXP = player.currentXP or 0
	
	-- Obliczenie skalowania przy starcie
	self:recalculateWindowScale()
end

-- Oblicza skalę okna na podstawie szerokości ekranu
function Leveling:recalculateWindowScale()
	local screenW = love.graphics.getWidth() or BASE_SCREEN_W
	-- Skalowanie okna na podstawie proporcji ekranu do wartości bazowej (max 1.0)
	local newScale = math.min(1.0, screenW / BASE_SCREEN_W)
	Leveling.window.scale = newScale
	Leveling.window.width = BASE_WINDOW_WIDTH * newScale
	Leveling.window.height = BASE_WINDOW_HEIGHT * newScale
end


-- Funkcja dodająca XP (wywoływana po zabiciu wroga w enemieslogic.lua)
function Leveling:addXP(enemyId)
	if Leveling.currentLevel >= Leveling.levelCap then return end
	
	local xpGained = ENEMY_XP_VALUE 
	Leveling.currentXP = Leveling.currentXP + xpGained
	
	while Leveling.currentXP >= Leveling.XPToNextLevel do
		Leveling.currentLevel = Leveling.currentLevel + 1
		Leveling.attributePoints = Leveling.attributePoints + 1
		Leveling.currentXP = Leveling.currentXP - Leveling.XPToNextLevel
		Leveling.XPToNextLevel = calculateXP(Leveling.currentLevel)
		
		-- Aktywacja okna ulepszeń
		Leveling.levelUpAvailable = true
		Leveling.selectedAttribute = 1 
		player.isLevelingUp = true
		
		if Leveling.currentLevel >= Leveling.levelCap then break end
	end
end

-- Aktualizuje statystyki gracza po awansie
function Leveling:applyUpgrade(attributeKey)
	if Leveling.attributePoints < 1 then return end
	
	local upgrade = Leveling.upgradeStats[attributeKey]
	if not upgrade then return end
	
	local pointsKey = upgrade.baseKey .. "Points"

	if player[pointsKey] ~= nil then
		-- Dla większości atrybutów wartość to procent, dla SPEED to wartość płaska
		player[pointsKey] = player[pointsKey] + upgrade.value
		Leveling:recalculateStats(attributeKey)

		Leveling.attributePoints = Leveling.attributePoints - 1
		
		if Leveling.attributePoints == 0 then
			Leveling.levelUpAvailable = false
			player.isLevelingUp = false
		end
	end
end

-- Obsługa klawiatury dla okna Level Up
function Leveling:keypressed(key)
	if not Leveling.levelUpAvailable then return end

	local mappedKey = _G.MapKey and _G.MapKey(key) or key
	local maxAttributes = #Leveling.attributes

	if mappedKey == "up" or key == "up" or mappedKey == "w" or key == "w" then
		Leveling.selectedAttribute = math.max(1, Leveling.selectedAttribute - 1)
	elseif mappedKey == "down" or key == "down" or mappedKey == "s" or key == "s" then
		Leveling.selectedAttribute = math.min(maxAttributes, Leveling.selectedAttribute + 1)
	elseif key == "return" or key == "space" or key == "kpenter" or key == "e" then 
		local attributeKey = Leveling.attributes[Leveling.selectedAttribute]
		Leveling:applyUpgrade(attributeKey)
	end
end


-- Obsługa kliknięcia/dotyku myszą na przyciski ulepszeń
function Leveling:mousepressed(x, y, button)
	-- Akceptujemy tylko lewy przycisk myszy (1) lub dotyk (1)
	if not Leveling.levelUpAvailable or button ~= 1 then return false end
	
	-- Ponowne przeliczenie skali na wypadek zmiany rozmiaru okna/ekranu
	self:recalculateWindowScale() 

	local win = Leveling.window
	local scale = win.scale
	
	-- Wartości bazowe skalowane
	local padding = 40 * scale
	local buttonH = 40 * scale
	local margin = 10 * scale
	local sideMargin = 20 * scale

	local screenWidth = love.graphics.getWidth()
	local winX = (screenWidth / 2) - (win.width / 2) 
	local winY = 50 * scale -- Stała pozycja Y (skalowana)
	
	-- Sprawdzamy kliknięcie wewnątrz okna w pierwszej kolejności
	if not (x >= winX and x <= winX + win.width and y >= winY and y <= winY + win.height) then
		return false -- Kliknięto poza oknem ulepszeń
	end
	
	for i, attr in ipairs(Leveling.attributes) do
		local btnY = winY + padding + (i * (buttonH + margin)) 
		local btnX = winX + sideMargin
		local btnW = win.width - (sideMargin * 2)
		
		-- Dotyk w przycisk
		if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + buttonH then
			Leveling.selectedAttribute = i -- Zaznaczenie przycisku (dla wizualizacji)
			Leveling:applyUpgrade(attr) -- Zastosowanie ulepszenia
			return true -- Zwracamy true, aby kontroler wiedział, że obsłużono wejście
		end
	end
	
	return false
end


-- RYSOWANIE

function Leveling:draw()
	-- Musimy przeliczyć skalę przed rysowaniem, na wypadek resize okna
	self:recalculateWindowScale()
	
	-- Rysuje pasek XP 
	self:drawXPBar()
	
	if not Leveling.levelUpAvailable then return end
	
	local win = Leveling.window
	local scale = win.scale

	-- Wartości bazowe skalowane
	local padding = 40 * scale
	local buttonH = 40 * scale
	local margin = 10 * scale
	local sideMargin = 20 * scale

	local screenWidth = love.graphics.getWidth()
	local winX = (screenWidth / 2) - (win.width / 2) 
	local winY = 50 * scale 
	
	-- Przyciemnienie ekranu
	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", 0, 0, screenWidth, love.graphics.getHeight())
	
	-- Tło okna
	love.graphics.setColor(0.1, 0.1, 0.2, 1)
	love.graphics.rectangle("fill", winX, winY, win.width, win.height, 10 * scale) 
	
	-- Ramka
	love.graphics.setColor(0.8, 0.8, 1, 1)
	love.graphics.rectangle("line", winX, winY, win.width, win.height, 10 * scale) 
	
	-- Tytuł
	love.graphics.setColor(1, 1, 1)
	local title = "LEVEL UP! (" .. Leveling.attributePoints .. " points)"
	
	-- Użycie push/pop i skalowanie fontu, aby tekst nie był za mały/duży
	love.graphics.push()
	love.graphics.scale(scale, scale)
	love.graphics.printf(title, winX/scale, (winY + 10)/scale, win.width/scale, "center") 
	love.graphics.pop()
	
	-- Instrukcja
	love.graphics.push()
	love.graphics.scale(scale * 0.7, scale * 0.7) -- Mniejsza skala dla podpowiedzi
	local instructionText = "Wybierz atrybut. Użyj ENTER/E do potwierdzenia lub kliknij przycisk."
	love.graphics.setColor(1, 1, 1, 0.8)
	love.graphics.printf(instructionText, winX/(scale * 0.7), (winY + win.height - 30)/(scale * 0.7), win.width/(scale * 0.7), "center")
	love.graphics.pop()
	
	-- Przyciski ulepszeń
	for i, attr in ipairs(Leveling.attributes) do
		local upgrade = Leveling.upgradeStats[attr]
		-- Korekta Y - Używamy i+1, bo tytuł zajmuje pierwszą linię (padding)
		local btnY = winY + padding + (i * (buttonH + margin)) 
		local btnX = winX + sideMargin 
		local btnW = win.width - (sideMargin * 2)
		
		-- Podświetlenie wybranego przycisku
		if i == Leveling.selectedAttribute then
			love.graphics.setColor(0.9, 0.5, 0.1, 1)
			love.graphics.setLineWidth(3 * scale)
			love.graphics.rectangle("line", btnX - (5 * scale), btnY - (5 * scale), btnW + (10 * scale), buttonH + (10 * scale), 5 * scale)
			love.graphics.setLineWidth(1)
		end
		
		-- Tło przycisku
		love.graphics.setColor(0.3, 0.3, 0.5)
		love.graphics.rectangle("fill", btnX, btnY, btnW, buttonH, 5 * scale)
		
		-- Ramka przycisku
		love.graphics.setColor(0.8, 0.8, 1)
		love.graphics.rectangle("line", btnX, btnY, btnW, buttonH, 5 * scale)
		
		-- Rysowanie tekstu z uwzględnieniem skalowania
		love.graphics.push()
		love.graphics.scale(scale, scale)

		-- Tekst atrybutu
		local statText = string.format("%s", upgrade.name)
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf(statText, btnX/scale, (btnY + 5)/scale, btnW/scale, "center")
		
		-- Obecna wartość
		local currentVal
		if attr == "HP" then currentVal = player.maxHp
		elseif attr == "STR" then currentVal = player.damage
		elseif attr == "MANA" then currentVal = player.maxMana
		elseif attr == "STAMINA" then currentVal = player.maxStamina
		elseif attr == "SPEED" then currentVal = player.speed end
		
		local valText = string.format("Current: %s", math.floor(currentVal))
		love.graphics.printf(valText, btnX/scale, (btnY + 25)/scale, btnW/scale, "center")

		love.graphics.pop()
	end
	
	love.graphics.setColor(1, 1, 1)
end

-- Rysuje pasek XP
function Leveling:drawXPBar()
	-- Wartości niezależne od głównego skalowania okna, ale oparte na stałych UI
	local uiScale = 1.0 
	local barWidth = 200 * uiScale
	local barHeight = 15 * uiScale
	local uiX = 10 * uiScale
	-- Pozycja Y ustawiona pod innymi paskami (HP, MANA, STAMINA)
	local uiY = (60) * uiScale 
	
	local xpPercent = math.max(0, math.min(Leveling.currentXP / Leveling.XPToNextLevel, 1))

	-- Tło
	love.graphics.setColor(0.1, 0.1, 0.3)
	love.graphics.rectangle("fill", uiX, uiY, barWidth, barHeight, 3, 3)

	-- Wypełnienie XP
	love.graphics.setColor(0.2, 0.8, 0.8)
	love.graphics.rectangle("fill", uiX, uiY, xpPercent * barWidth, barHeight, 3, 3)

	-- Obramowanie
	love.graphics.setColor(1, 1, 1)
	love.graphics.rectangle("line", uiX, uiY, barWidth, barHeight, 3, 3)
	
	-- Tekst XP
	local xpText = string.format("Level %d | XP: %d / %d", 
								Leveling.currentLevel, 
								math.floor(Leveling.currentXP), 
								math.floor(Leveling.XPToNextLevel))
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf(xpText, uiX, uiY + barHeight/2 - 6, barWidth, "center")
end


return Leveling