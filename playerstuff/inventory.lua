local inventory = {}
local love = love or {}
local math = math or {}

-- ============================================================
-- KONFIGURACJA I STAŁE (TUTAJ EDYTUJ WYGLĄD)
-- ============================================================

local smallFont
local WARRIOR_IMAGE_PATH = "sprites/warrior.png"
local INVENTORY_BG_PATH = "sprites/inventorybg.png"

-- 1. GLÓWNA SIATKA (PLECAK)
local SLOT_SIZE = 64-- Wielkość jednego kwadratu w plecaku (px)
local PADDING = 10-- Odstęp między kwadratami w plecaku (px)
local COLS = 6-- Liczba kolumn w plecaku
local ROWS = 4-- Liczba wierszy w plecaku
local SPACING_BETWEEN_PANELS = 50-- Odstęp między panelem postaci a plecakiem

-- 2. PANEL WYPOSAŻENIA (POSTAĆ)
local EQ_PANEL_W = 320-- Bazowa szerokość panelu z postacią
local EQ_PANEL_H_BASE = 320--BAZOWA WYSOKOŚĆ PANELU POSTACI (px). Ustaw tę wartość, by kontrolować wysokość. Będzie co najmniej równa minimalnej wysokości slotów.**
local EQ_SLOT_SIZE = 64-- Wielkość slotów na wyposażenie (np. hełm, broń)
local EQ_PAD = 16-- Odstęp pionowy między slotami w panelu EQ

-- Pozycje elementów wewnątrz panelu EQ (współczynniki 0.0 - 1.0)
local EQ_SLOTS_LEFT_X_RATIO = 0.12-- Pozioma pozycja lewych slotów (12% szerokości panelu)
local EQ_SLOTS_RIGHT_X_RATIO = 0.88-- Pozioma pozycja prawych slotów (88% szerokości panelu)
local EQ_SLOTS_START_Y_OFFSET = 20-- Odsunięcie pierwszego slotu od góry panelu (w pixelach bazowych)

-- Ustawienia obrazka Wojownika
local WARRIOR_IMG_Y_POS_RATIO = 0.4-- Pionowa pozycja środka obrazka (40% wysokości panelu)
local WARRIOR_IMG_SCALE_RATIO = 0.6-- Jak duży ma być obrazek względem szerokości panelu (60%)

-- 3. PANEL OPISU (NA DOLE)
local DESC_PANEL_H = 75-- Wysokość panelu z opisem
local DESC_PANEL_V_SPACING = 30-- Odstęp pionowy panelu opisu od reszty

-- 4. SKALOWANIE UI
local MIN_UI_SCALE = 0.45-- Minimalna wielkość UI
local MAX_UI_SCALE = 1.2-- Maksymalna wielkość UI

-- ============================================================
-- INICJALIZACJA I POZYCJONOWANIE
-- ============================================================

function inventory:init()
	-- Ładowanie czcionki
	if love.graphics and not smallFont then
		smallFont = love.graphics.newFont(11)
	end

	-- Podstawowe zmienne stanu
	self.isOpen = false
	self.cols = COLS
	self.rows = ROWS
	
	-- Przypisanie konfiguracji do zmiennych obiektu (dla łatwiejszego dostępu)
	self.slotSize = SLOT_SIZE
	self.padding = PADDING
	self.eqPanelW = EQ_PANEL_W
	self.eqPanelHBase = EQ_PANEL_H_BASE 
	self.eqSlotSize = EQ_SLOT_SIZE
	self.eqPad = EQ_PAD
	self.spacing = SPACING_BETWEEN_PANELS
	self.descPanelH = DESC_PANEL_H
	self.descPanelVSpacing = DESC_PANEL_V_SPACING

	-- Tabela przedmiotów
	self.items = {}
	for i = 1, self.rows * self.cols do
		self.items[i] = nil
	end

	-- Nawigacja
	self.selectedRow = 1
	self.selectedCol = 1
	self.selectionMode = "main"

	-- Sloty wyposażenia
	self.equipped = {
		weapon = nil, artifact1 = nil, artifact2 = nil, artifact3 = nil,
		helmet = nil, chestplate = nil, leggins = nil, boots = nil
	}
	self.selectedEqRow = 1
	self.selectedEqCol = 1

	-- Mapa slotów EQ
	self.eqSlotMap = {
		[1] = { [1] = "weapon", [2] = "helmet" },
		[2] = { [1] = "artifact1", [2] = "chestplate" },
		[3] = { [1] = "artifact2", [2] = "leggins" },
		[4] = { [1] = "artifact3", [2] = "boots" },
	}

	-- Obrazek postaci
	self.warriorImage = nil
	-- ZMIANA 2: Nowa zmienna dla obrazka tła
	self.inventoryBgImage = nil 

	if love.image and love.graphics then
		local ok, imgOrErr = pcall(function()
			if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(WARRIOR_IMAGE_PATH) then
				local imgData = love.image.newImageData(WARRIOR_IMAGE_PATH)
				return love.graphics.newImage(imgData)
			else
				return love.graphics.newImage(WARRIOR_IMAGE_PATH)
			end
		end)
		if ok then self.warriorImage = imgOrErr end
		
		-- ZMIANA 2: Ładowanie obrazka tła
		local okBg, imgBgOrErr = pcall(function()
			return love.graphics.newImage(INVENTORY_BG_PATH)
		end)
		if okBg then self.inventoryBgImage = imgBgOrErr end
	end

	-- Drag & Drop
	self.dragItem = nil
	self.dragIndex = nil
	self.dragX = 0
	self.dragY = 0

	-- Pierwsze obliczenie pozycji
	if love.graphics and love.graphics.getWidth and love.graphics.getHeight then
		self:recalculatePosition()
	end
end

function inventory:recalculatePosition()
	local screenW = love.graphics.getWidth()
	local screenH = love.graphics.getHeight()

	-- 1. Obliczenie wymiarów "projektowych" (przed skalowaniem)
	local designMainGridW = COLS * SLOT_SIZE + (COLS - 1) * PADDING
	local designMainGridH = ROWS * SLOT_SIZE + (ROWS - 1) * PADDING
	
	-- Minimalna wysokość, aby sloty wyposażenia się zmieściły
	local minEqSlotHeight = EQ_SLOT_SIZE * 4 + EQ_PAD * 3 + EQ_SLOTS_START_Y_OFFSET * 2
	
	-- Wysokość panelu EQ to max(bazowa wysokość ustawiona przez użytkownika, minimalna wymagana przez sloty)
	local designEqH = math.max(EQ_PANEL_H_BASE, minEqSlotHeight)
	
	-- Całkowite wymiary do skalowania
	local designTotalW = EQ_PANEL_W + designMainGridW + SPACING_BETWEEN_PANELS
	local designMaxH = math.max(designEqH, designMainGridH)
	local designTotalH = designMaxH + DESC_PANEL_V_SPACING + DESC_PANEL_H

	-- 2. Obliczenie skali, aby wszystko zmieściło się na ekranie
	local margin = 20
	local maxWScale = (screenW - margin * 2) / designTotalW
	local maxHScale = (screenH - margin * 2) / designTotalH
	local calculatedScale = math.min(maxWScale, maxHScale, MAX_UI_SCALE)
	
	if calculatedScale ~= calculatedScale then calculatedScale = 1 end -- NaN fix
	self.scale = math.max(MIN_UI_SCALE, math.min(MAX_UI_SCALE, calculatedScale))

	-- Fix dla mobile
	local osname = "Unknown"
	if love.system and love.system.getOS then osname = love.system.getOS() end
	self.isMobile = (osname == "Android" or osname == "iOS")
	if self.isMobile then
		self.scale = math.max(MIN_UI_SCALE, math.min(self.scale, 0.9))
	end

	-- 3. Przeliczenie wymiarów na piksele (z uwzględnieniem skali)
	self.slotSizeScaled = math.max(8, math.floor(SLOT_SIZE * self.scale))
	self.paddingScaled = math.max(0, math.floor(PADDING * self.scale))
	
	self.eqSlotSizeScaled = math.max(8, math.floor(EQ_SLOT_SIZE * self.scale))
	self.eqPanelWScaled = math.max(16, math.floor(EQ_PANEL_W * self.scale))
	
	self.spacingScaled = math.max(0, math.floor(SPACING_BETWEEN_PANELS * self.scale))
	self.descPanelHScaled = math.max(16, math.floor(DESC_PANEL_H * self.scale))
	self.descPanelVSpacingScaled = math.max(0, math.floor(DESC_PANEL_V_SPACING * self.scale))

	-- Wymiary kontenerów po przeskalowaniu
	local mainGridW = self.cols * self.slotSizeScaled + (self.cols - 1) * self.paddingScaled
	local mainGridH = self.rows * self.slotSizeScaled + (self.rows - 1) * self.paddingScaled
	
	-- Wysokość Panelu EQ (używamy designEqH, która już jest zabezpieczona minimum i przeskalowana)
	self.eqPanelHScaled = math.max(math.floor(designEqH * self.scale), 
									mainGridH * 0.5) -- Upewniamy się, że nie jest za mała (dodatkowe zabezpieczenie)

	local eqPanelH = self.eqPanelHScaled
	
	-- 4. Centrowanie całości na ekranie
	local totalContentW = self.eqPanelWScaled + mainGridW + self.spacingScaled
	local totalMaxH = math.max(eqPanelH, mainGridH)
	local totalContentH = totalMaxH + self.descPanelVSpacingScaled + self.descPanelHScaled

	local centeredX = (screenW - totalContentW) / 2
	local centeredY = (screenH - totalContentH) / 2
	
	-- ZMIANA 2: Dodanie pozycji i wymiarów dla całego bloku (tła)
	self.bgX = math.floor(centeredX)
	self.bgY = math.floor(centeredY)
	self.bgW = totalContentW
	self.bgH = totalContentH

	-- Ustawianie pozycji Y dla Plecaka i Panelu EQ (środkowanie pionowe)
	local mainPanelY = self.bgY -- Używamy Y całego bloku
	self.eqPanelY = mainPanelY + math.floor((totalMaxH - eqPanelH) / 2)
	self.y = mainPanelY + math.floor((totalMaxH - mainGridH) / 2)

	self.eqPanelX = self.bgX -- Używamy X całego bloku
	self.mainPanelX = self.eqPanelX
	
	-- Siatka przedmiotów jest przesunięta w prawo względem panelu postaci
	self.x = self.eqPanelX + self.eqPanelWScaled + self.spacingScaled

	-- Panel opisu na dole
	self.descPanelX = self.eqPanelX
	self.descPanelY = mainPanelY + totalMaxH + self.descPanelVSpacingScaled
	self.descPanelW = totalContentW
	self.descPanelH = self.descPanelHScaled

	-- 5. Obliczanie pozycji slotów wewnątrz panelu EQ 
	local eqW = self.eqPanelWScaled
	local startYOffset = math.floor(EQ_SLOTS_START_Y_OFFSET * self.scale)
	local startY = self.eqPanelY + startYOffset
	
	local leftX = self.eqPanelX + math.floor(eqW * EQ_SLOTS_LEFT_X_RATIO)
	local rightX = self.eqPanelX + math.floor(eqW * EQ_SLOTS_RIGHT_X_RATIO) - self.eqSlotSizeScaled

	-- Odstęp pionowy między slotami
	local pad = self.eqSlotSizeScaled + math.floor(EQ_PAD * self.scale)

	self.slotPositions = {
		weapon = {x = leftX,y = startY + 0 * pad},
		artifact1 = {x = leftX,y = startY + 1 * pad},
		artifact2 = {x = leftX,y = startY + 2 * pad},
		artifact3 = {x = leftX,y = startY + 3 * pad},
		
		helmet = {x = rightX,y = startY + 0 * pad},
		chestplate = {x = rightX,y = startY + 1 * pad},
		leggins = {x = rightX,y = startY + 2 * pad},
		boots = {x = rightX,y = startY + 3 * pad}
	}

	-- Aktualizacja czcionki
	if love.graphics then
		local baseSmall = 11
		local fontSize = math.max(8, math.floor(baseSmall * self.scale))
		if not smallFont or (smallFont and smallFont:getHeight() ~= love.graphics.newFont(fontSize):getHeight()) then
			smallFont = love.graphics.newFont(fontSize)
		end
	end
end

function inventory:onResize()
	if love.graphics and love.graphics.getWidth then
		self:recalculatePosition()
	end
end

function inventory:toggle()
	self.isOpen = not self.isOpen
	if self.isOpen then
		self:recalculatePosition()
	end
end

-- ============================================================
-- LOGIKA PRZEDMIOTÓW (BEZ ZMIAN)
-- ============================================================

function inventory:getBonuses()
	local totalBonuses = { hp = 0, mana = 0, stamina = 0, speed = 0, str = 0 }
	for slot, item in pairs(self.equipped) do
		if item and item.data and item.data.bonuses then
			for stat, value in pairs(item.data.bonuses) do
				if totalBonuses[stat] ~= nil then
					totalBonuses[stat] = totalBonuses[stat] + value
				end
			end
		end
	end
	return totalBonuses
end

function inventory:getEquippedWeapon()
	return self.equipped.weapon
end

function inventory:removeItemFromMain(item)
	for i = 1, self.rows * self.cols do
		if self.items[i] == item then
			self.items[i] = nil
			return
		end
	end
end

function inventory:equipItem(item)
	if not item or not item.data then return end
	local itemType = item.data.type or "misc"
	local slot = nil

	if itemType == "artifact" then
		for i = 1, 3 do
			if not self.equipped["artifact"..i] then
				slot = "artifact"..i
				break
			end
		end
	elseif itemType == "weapon" or itemType == "helmet" or itemType == "chestplate" or itemType == "leggins" or itemType == "boots" then
		slot = itemType
	end

	if not slot then return end

	if self.equipped[slot] and self.equipped[slot] ~= item then
		local oldItem = self.equipped[slot]
		oldItem.equipped = false
		local placed = false
		for i = 1, self.rows * self.cols do
			if not self.items[i] then
				self.items[i] = oldItem
				placed = true
				break
			end
		end
		if not placed then
			table.insert(self.items, oldItem)
		end
	end

	self.equipped[slot] = item
	item.equipped = true
	self:removeItemFromMain(item)

	if player and player.calculateStats then player:calculateStats() end
end

function inventory:unequipItem(slotName)
	local item = self.equipped[slotName]
	if not item then return end
	item.equipped = false
	self.equipped[slotName] = nil

	local placed = false
	for i = 1, self.rows * self.cols do
		if not self.items[i] then
			self.items[i] = item
			placed = true
			break
		end
	end
	if not placed then
		table.insert(self.items, item)
	end
	if player and player.calculateStats then player:calculateStats() end
end

-- ============================================================
-- OBSŁUGA WEJŚCIA
-- ============================================================

function inventory:getEqSlotBySelection()
	local row = self.selectedEqRow
	local col = self.selectedEqCol
	local map = self.eqSlotMap
	return map[row] and map[row][col]
end

function inventory:getItemAtScreen(x, y)
	-- Plecak
	for row = 1, self.rows do
		for col = 1, self.cols do
			local index = (row - 1) * self.cols + col
			local slotX = self.x + (col - 1) * (self.slotSizeScaled + self.paddingScaled)
			local slotY = self.y + (row - 1) * (self.slotSizeScaled + self.paddingScaled)
			local w = self.slotSizeScaled
			local h = self.slotSizeScaled
			if x >= slotX and x <= slotX + w and y >= slotY and y <= slotY + h then
				return self.items[index], index, "main", slotX, slotY
			end
		end
	end

	-- Ekwipunek
	for name, pos in pairs(self.slotPositions) do
		local slotX = pos.x
		local slotY = pos.y
		local slotW = self.eqSlotSizeScaled
		local slotH = self.eqSlotSizeScaled
		if x >= slotX and x <= slotX + slotW and y >= slotY and y <= slotY + slotH then
			return self.equipped[name], name, "eq", slotX, slotY
		end
	end

	return nil, nil, nil, nil, nil
end

local function normalizeTouchCoords(x, y)
	if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
		local sx = love.graphics.getWidth()
		local sy = love.graphics.getHeight()
		return x * sx, y * sy
	end
	return x, y
end

function inventory:mousepressed(x, y, button)
	if not self.isOpen then return end
	if button ~= 1 then return end
	local item, idxOrName, typ = self:getItemAtScreen(x, y)
	if item then
		self.dragItem = item
		self.dragIndex = idxOrName
		self.dragX = x
		self.dragY = y
	end
end

function inventory:mousemoved(x, y, dx, dy, istouch)
	if not self.isOpen then return end
	if not self.dragItem then return end
	self.dragX = x
	self.dragY = y
end

function inventory:mousereleased(x, y, button)
	if not self.isOpen then return end
	if button ~= 1 then return end
	if not self.dragItem then return end

	local item, idxOrName, typ = self:getItemAtScreen(x, y)

	if typ == "main" and idxOrName and self.dragIndex and idxOrName ~= self.dragIndex and type(self.dragIndex) == "number" then
		self.items[self.dragIndex], self.items[idxOrName] = self.items[idxOrName], self.items[self.dragIndex]
	end

	if typ == "eq" and idxOrName and self.dragIndex then
		local dragged = nil
		if type(self.dragIndex) == "number" then
			dragged = self.items[self.dragIndex]
		end
		if dragged and dragged.data and dragged.data.type then
			self:equipItem(dragged)
		end
	end

	if typ == "main" and type(self.dragIndex) == "string" then
		self:unequipItem(self.dragIndex)
	end

	self.dragItem = nil
	self.dragIndex = nil
end

function inventory:touchpressed(id, x, y, pressure)
	if not self.isOpen then return end
	local tx, ty = normalizeTouchCoords(x, y)
	local item, idxOrName, typ = self:getItemAtScreen(tx, ty)
	if item then
		self.dragItem = item
		self.dragIndex = idxOrName
		self.dragX = tx
		self.dragY = ty
	end
end

function inventory:touchmoved(id, x, y, pressure)
	if not self.isOpen then return end
	if not self.dragItem then return end
	local tx, ty = normalizeTouchCoords(x, y)
	self.dragX = tx
	self.dragY = ty
end

function inventory:touchreleased(id, x, y, pressure)
	if not self.isOpen then return end
	if not self.dragItem then return end
	local tx, ty = normalizeTouchCoords(x, y)
	local item, idxOrName, typ = self:getItemAtScreen(tx, ty)

	if typ == "main" and idxOrName and self.dragIndex and idxOrName ~= self.dragIndex and type(self.dragIndex) == "number" then
		self.items[self.dragIndex], self.items[idxOrName] = self.items[idxOrName], self.items[self.dragIndex]
	end
	
	if typ == "eq" and idxOrName and self.dragIndex and type(self.dragIndex) == "number" then
		local dragged = self.items[self.dragIndex]
		if dragged and dragged.data and dragged.data.type then
			self:equipItem(dragged)
		end
	end

	if typ == "main" and type(self.dragIndex) == "string" then
		self:unequipItem(self.dragIndex)
	end

	self.dragItem = nil
	self.dragIndex = nil
end

local function inventoryMainKeypressed(key)
	local maxRowMain = inventory.rows
	local maxColMain = inventory.cols

	if key == "right" then
		inventory.selectedCol = math.min(inventory.selectedCol + 1, maxColMain)
	elseif key == "left" then
		if inventory.selectedCol == 1 then
			inventory.selectionMode = "equipped"
			inventory.selectedEqRow = math.min(inventory.selectedRow, 4)
			inventory.selectedEqCol = 2
			return
		end
		inventory.selectedCol = math.max(inventory.selectedCol - 1, 1)
	elseif key == "down" then
		if inventory.selectedRow < maxRowMain then inventory.selectedRow = inventory.selectedRow + 1 end
	elseif key == "up" then
		inventory.selectedRow = math.max(inventory.selectedRow - 1, 1)
	end

	if key == "return" then
		local index = (inventory.selectedRow - 1) * maxColMain + inventory.selectedCol
		local selectedItem = inventory.items[index]
		if selectedItem then inventory:equipItem(selectedItem) end
	end
end

local function inventoryEquippedKeypressed(key)
	local maxRowEq = 4
	local maxColEq = 2

	if key == "right" then
		if inventory.selectedEqCol == 2 then
			inventory.selectionMode = "main"
			inventory.selectedRow = math.max(1, math.min(inventory.selectedEqRow, inventory.rows))
			inventory.selectedCol = 1
			return
		end
		inventory.selectedEqCol = math.min(inventory.selectedEqCol + 1, maxColEq)
	elseif key == "left" then
		inventory.selectedEqCol = math.max(inventory.selectedEqCol - 1, 1)
	elseif key == "down" then
		inventory.selectedEqRow = math.min(inventory.selectedEqRow + 1, maxRowEq)
	elseif key == "up" then
		inventory.selectedEqRow = math.max(inventory.selectedEqRow - 1, 1)
	end

	if key == "return" then
		local slotName = inventory:getEqSlotBySelection()
		if slotName then inventory:unequipItem(slotName) end
	end
end

function inventory:keypressed(key)
	if not self.isOpen then return end
	local myKey = MapKey and MapKey(key) or key
	
	if self.selectionMode == "main" then 
		inventoryMainKeypressed(myKey)
	elseif self.selectionMode == "equipped" then 
		inventoryEquippedKeypressed(myKey) 
	end
end

-- ============================================================
-- RYSOWANIE (RENDER)
-- ============================================================

function inventory:draw()
	if not self.isOpen then return end

	-- ZMIANA 3: Rysowanie obrazka tła (jako pierwsza warstwa)
	if self.inventoryBgImage then
		local img = self.inventoryBgImage
		local scaleBgW = self.bgW / img:getWidth()
		local scaleBgH = self.bgH / img:getHeight()

		love.graphics.setColor(1, 1, 1) -- Upewnij się, że kolor jest biały (1,1,1)
		love.graphics.draw(img, self.bgX, self.bgY, 0, scaleBgW, scaleBgH)
	end

	-- 1. Rysowanie plecaka (samych slotów)
	for row = 1, self.rows do
		for col = 1, self.cols do
			local index = (row - 1) * self.cols + col
			local item = self.items[index]
			local x = self.x + (col - 1) * (self.slotSizeScaled + self.paddingScaled)
			local y = self.y + (row - 1) * (self.slotSizeScaled + self.paddingScaled)
			local s = self.slotSizeScaled

			love.graphics.setColor(0.2, 0.2, 0.2)
			love.graphics.rectangle("fill", x, y, s, s, 5 * self.scale, 5 * self.scale) -- Zachowujemy tło samego slotu

			if self.selectionMode == "main" and row == self.selectedRow and col == self.selectedCol then
				love.graphics.setColor(1, 1, 0)
				love.graphics.setLineWidth(math.max(1, 3 * self.scale))
				love.graphics.rectangle("line", x, y, s, s, 5 * self.scale, 5 * self.scale)
				love.graphics.setLineWidth(1)
			end

			if item and item.data and item.data.image then
				love.graphics.setColor(1, 1, 1)
				local img = item.data.image
				local scaleImg = math.min((s - 10) / img:getWidth(), (s - 10) / img:getHeight())
				love.graphics.draw(img, x + s / 2, y + s / 2, 0, scaleImg, scaleImg, img:getWidth() / 2, img:getHeight() / 2)
				
				if item.amount and item.amount > 1 then
					love.graphics.setFont(smallFont or love.graphics.getFont())
					love.graphics.setColor(1, 1, 0)
					love.graphics.print(tostring(item.amount), x + s - math.floor(12 * self.scale), y + s - math.floor(14 * self.scale))
					love.graphics.setColor(1, 1, 1)
				end
			end
		end
	end

	-- Wybór przedmiotu do opisu
	local selectedItem = nil
	if self.selectionMode == "main" then
		local selectedIndex = (self.selectedRow - 1) * self.cols + self.selectedCol
		selectedItem = self.items[selectedIndex]
	elseif self.selectionMode == "equipped" then
		local slotName = self:getEqSlotBySelection()
		if slotName then selectedItem = self.equipped[slotName] end
	end

	-- 2. Rysowanie panelu opisu
	local panelX = self.descPanelX
	local panelY = self.descPanelY
	local panelWidth = self.descPanelW
	local panelHeight = self.descPanelH

	-- ZMIANA 4: USUNIĘTO RYSOWANIE SZAREGO TŁA/RAMKI (pokrywa to teraz inventorybg.png)
	-- love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
	-- love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8 * self.scale, 8 * self.scale)
	-- love.graphics.setColor(1, 1, 1)
	-- love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8 * self.scale, 8 * self.scale)

	love.graphics.setFont(love.graphics.getFont())
	if selectedItem and selectedItem.data then
		local amountText = selectedItem.amount and " x" .. selectedItem.amount or ""
		love.graphics.printf("Item: " .. (selectedItem.data.name or "<unknown>") .. amountText, panelX + 8 * self.scale, panelY + 8 * self.scale, panelWidth - 16 * self.scale, "left")
		love.graphics.printf("Description:\n" .. (selectedItem.data.desc or ""), panelX + 8 * self.scale, panelY + 28 * self.scale, panelWidth - 16 * self.scale, "left")
		local statusText = selectedItem.equipped and "Equipped" or "Unequipped"
		love.graphics.printf("Status: " .. statusText, panelX + 8 * self.scale, panelY + panelHeight - 20 * self.scale, panelWidth - 16 * self.scale, "left")
	else
		love.graphics.printf("Empty slot", panelX + 8 * self.scale, panelY + 8 * self.scale, panelWidth - 16 * self.scale, "left")
	end

	-- 3. Rysowanie panelu postaci
	local eqPanelX = self.eqPanelX
	local eqPanelY = self.eqPanelY
	local eqPanelW = self.eqPanelWScaled
	local eqPanelH = self.eqPanelHScaled

	-- ZMIANA 4: USUNIĘTO RYSOWANIE SZAREGO TŁA/RAMKI (pokrywa to teraz inventorybg.png)
	-- love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
	-- love.graphics.rectangle("fill", eqPanelX, eqPanelY, eqPanelW, eqPanelH, 8 * self.scale, 8 * self.scale)
	-- love.graphics.setColor(1, 1, 1)
	-- love.graphics.rectangle("line", eqPanelX, eqPanelY, eqPanelW, eqPanelH, 8 * self.scale, 8 * self.scale)

	-- Rysowanie wojownika (używamy zmiennych konfiguracyjnych)
	if self.warriorImage then
		local img = self.warriorImage
		local imgX = eqPanelX + eqPanelW / 2
		
		-- Użycie WARRIOR_IMG_Y_POS_RATIO z konfiguracji
		local imgY = eqPanelY + math.floor(eqPanelH * WARRIOR_IMG_Y_POS_RATIO)
		
		-- Użycie WARRIOR_IMG_SCALE_RATIO z konfiguracji
		local scaleImg = (eqPanelW * WARRIOR_IMG_SCALE_RATIO) / img:getWidth()
		scaleImg = math.min(scaleImg, 1.0)
		
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(img, imgX, imgY, 0, scaleImg, scaleImg, img:getWidth() / 2, img:getHeight() / 2)
	end

	-- Rysowanie slotów EQ
	local eqSlotSelectionMap = self.eqSlotMap
	local currentEqSelection = self:getEqSlotBySelection()
	love.graphics.setFont(smallFont or love.graphics.getFont())

	for row = 1, 4 do
		for col = 1, 2 do
			local name = eqSlotSelectionMap[row][col]
			local pos = self.slotPositions[name]
			local slotX = pos.x
			local slotY = pos.y
			local slotW = self.eqSlotSizeScaled
			local slotH = self.eqSlotSizeScaled

			love.graphics.setColor(0.2, 0.2, 0.2)
			love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 5 * self.scale, 5 * self.scale) -- Zachowujemy tło samego slotu

			love.graphics.setColor(1, 1, 1)
			love.graphics.printf(name:upper(), slotX - math.floor(20 * self.scale), slotY - math.floor(12 * self.scale), math.floor(100 * self.scale), "center", 0, 1, 1)

			local item = self.equipped[name]
			if item and item.data and item.data.image then
				local img = item.data.image
				love.graphics.setColor(1, 1, 1)
				local imgScale = math.min((slotW - 8) / img:getWidth(), (slotH - 8) / img:getHeight()) * 0.95
				love.graphics.draw(img, slotX + slotW / 2, slotY + slotH / 2, 0, imgScale, imgScale, img:getWidth() / 2, img:getHeight() / 2)
			end

			if self.selectionMode == "equipped" and currentEqSelection == name then
				love.graphics.setColor(1, 1, 0)
				love.graphics.setLineWidth(math.max(1, 3 * self.scale))
			else
				love.graphics.setColor(1, 1, 1)
				love.graphics.setLineWidth(1)
			end
			love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 5 * self.scale, 5 * self.scale)
		end
	end

	-- 4. Przeciągany przedmiot
	if self.dragItem then
		local dx = self.dragX or 0
		local dy = self.dragY or 0
		local item = self.dragItem
		if item and item.data and item.data.image then
			local img = item.data.image
			local s = self.slotSizeScaled
			local scaleImg = math.min((s - 10) / img:getWidth(), (s - 10) / img:getHeight())
			love.graphics.setColor(1, 1, 1, 0.95)
			love.graphics.draw(img, dx, dy, 0, scaleImg, scaleImg, img:getWidth() / 2, img:getHeight() / 2)
			love.graphics.setColor(1, 1, 1)
		end
	end

	love.graphics.setLineWidth(1)
	love.graphics.setColor(1, 1, 1)
end

return inventory