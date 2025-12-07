local quickslots = {}
local love = love or {}
local math = math or {}

local inventory = nil 

-- KLUCZOWA ZMIENNA SKALOWANIA INTERFEJSU (domyślnie 1.0)
local SLOT_SCALE = 1.2

-- Zmienne bazowe (przy skali 1.0)
local BASE_SLOT_SIZE = 64
local BASE_SELECTOR_SIZE = 56
local NUM_SLOTS = 3
local BASE_BOTTOM_MARGIN = 20

-- Obliczone dynamiczne wymiary
local SLOT_SIZE = BASE_SLOT_SIZE * SLOT_SCALE
local QUICKSLOT_H = SLOT_SIZE
local QUICKSLOT_W = SLOT_SIZE * NUM_SLOTS
local BOTTOM_MARGIN = BASE_BOTTOM_MARGIN * SLOT_SCALE

-- Zmienna obrazu (ścieżka jest stała)
local QUICKSLOT_IMAGE_PATH = "sprites/quickslotbar.png"

quickslots.mainInventoryIndices = { 0, 2, 3 }

quickslots.spritesheet = nil
quickslots.quads = {}
quickslots.currentSlot = 1 

function quickslots:setDependencies(inv)
	inventory = inv
end

function quickslots:init()
	if love.image and love.graphics and not self.spritesheet then
		local imgData = love.image.newImageData(QUICKSLOT_IMAGE_PATH)
		self.spritesheet = love.graphics.newImage(imgData)
	end
	
	-- Quady rysują domyślny rozmiar (64x64) z arkusza 192x64
	for i = 1, NUM_SLOTS do
		local x = (i - 1) * BASE_SLOT_SIZE
		local y = 0
		-- Używamy BASE_SLOT_SIZE dla quada, ponieważ odnosi się on do pixeli w obrazie, który ma 64x64
		self.quads[i] = love.graphics.newQuad(x, y, BASE_SLOT_SIZE, BASE_SLOT_SIZE, QUICKSLOT_W / SLOT_SCALE, QUICKSLOT_H / SLOT_SCALE)
	end
end

function quickslots:changeSlot(delta)
	self.currentSlot = self.currentSlot + delta
	if self.currentSlot < 1 then
		self.currentSlot = NUM_SLOTS
	elseif self.currentSlot > NUM_SLOTS then
		self.currentSlot = 1
	end
	self:useCurrentSlot()
end

local function getItemForQuickSlot(slotIndex)
	if not inventory then return nil end
	
	if slotIndex == 1 then
		return inventory.equipped.weapon
	else
		-- Slot 2 i 3 są narazie puste (zwracamy NIL)
		return nil
	end
end

function quickslots:draw()
	if not self.spritesheet or not inventory then return end
	
	local currentScreenW = love.graphics.getWidth()
	local currentScreenH = love.graphics.getHeight()
	
	local startX = (currentScreenW - QUICKSLOT_W) / 2
	local startY = currentScreenH - QUICKSLOT_H - BOTTOM_MARGIN

	for i = 1, NUM_SLOTS do
		local slotX = startX + (i - 1) * SLOT_SIZE
		local slotY = startY
		
		local item = getItemForQuickSlot(i) 

		-- 1. Rysowanie tła slota (używamy SLOT_SCALE do skalowania rysowanego obrazu)
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(self.spritesheet, self.quads[i], slotX, slotY, 0, SLOT_SCALE, SLOT_SCALE)

		-- 2. Rysowanie ramki aktywnego slota (żółty selektor)
		if i == self.currentSlot then
			local SELECTOR_SIZE = BASE_SELECTOR_SIZE * SLOT_SCALE
			local MARGIN = (SLOT_SIZE - SELECTOR_SIZE) / 2 -- Wciąż wycentrowane

			love.graphics.setColor(1, 1, 0)
			love.graphics.setLineWidth(3 * SLOT_SCALE) -- Skalowanie grubości linii
			love.graphics.rectangle("line", 
				slotX + MARGIN,
				slotY + MARGIN,
				SELECTOR_SIZE,
				SELECTOR_SIZE
			)
			love.graphics.setLineWidth(1)
		end
		
		-- 3. Rysowanie przedmiotu
		if item and item.data and item.data.image then
			local img = item.data.image
			love.graphics.setColor(1, 1, 1)
			
			-- Skalowanie obrazka itemu tak, by pasował do przeskalowanego slota
			local item_fit_size = (SLOT_SIZE - 10 * SLOT_SCALE)
			local scale = math.min(item_fit_size/img:getWidth(), item_fit_size/img:getHeight())
			
			love.graphics.draw(img, slotX+SLOT_SIZE/2, slotY+SLOT_SIZE/2, 0, scale, scale, img:getWidth()/2, img:getHeight()/2)
			
			-- Rysowanie ilości
			if i ~= 1 and item.amount and item.amount > 1 then 
				-- Tutaj musiałbyś skalować czcionkę, co wymagałoby użycia love.graphics.newFont.
				-- Na razie skalujemy tylko pozycję i zakładamy, że czcionka jest ustawiona:
				local currentFont = love.graphics.getFont()
				local smallFont = inventory.smallFont or currentFont
				
				love.graphics.setFont(smallFont) 
				love.graphics.setColor(1,1,0)
				
				-- Przeskalowane pozycjonowanie tekstu:
				love.graphics.print(tostring(item.amount), slotX + SLOT_SIZE - (15 * SLOT_SCALE), slotY + SLOT_SIZE - (18 * SLOT_SCALE))
				
				love.graphics.setFont(currentFont)
			end
		end

		-- 4. Rysowanie numeru klawisza (1, 2, 3)
		local currentFont = love.graphics.getFont()
		local smallFont = inventory.smallFont or currentFont
		love.graphics.setFont(smallFont)
		love.graphics.setColor(1,1,1)
		love.graphics.print(tostring(i), slotX + (5 * SLOT_SCALE), slotY + (5 * SLOT_SCALE))
		love.graphics.setFont(currentFont)
	end
	
	love.graphics.setColor(1, 1, 1)
end

function quickslots:useCurrentSlot()
	local item = getItemForQuickSlot(self.currentSlot)
	
	if self.currentSlot == 1 then
		if item then
			print("Wybrano wyposażoną broń: " .. item.data.name)
		else
			print("Slot 1 (Wyposażona broń) jest pusty.")
		end
	else
		print("Slot " .. self.currentSlot .. " jest narazie nieaktywny/pusty.")
	end
end

return quickslots