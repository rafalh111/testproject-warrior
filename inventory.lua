local inventory = {}
local love = love or {} 
local math = math or {}

local smallFont 
local WARRIOR_IMAGE_PATH = "sprites/warrior.png"

function inventory:init()
    if love.graphics and not smallFont then
        smallFont = love.graphics.newFont(11)
    end
    
    self.isOpen = false
    self.cols = 6
    self.rows = 4
    self.slotSize = 64
    self.padding = 10
    
    local screenW = 1280
    local screenH = 720 
    
    local mainGridW = self.cols * self.slotSize + (self.cols - 1) * self.padding
    local mainGridH = self.rows * self.slotSize + (self.rows - 1) * self.padding

    self.eqPanelW = 320
    self.eqPanelH = mainGridH
    
    local spacing = 50 
    local totalContentW = self.eqPanelW + mainGridW + spacing 
    
    self.mainPanelX = (screenW - totalContentW) / 4
    self.mainPanelY = 100
    
    self.eqPanelX = self.mainPanelX           
    self.eqPanelY = self.mainPanelY           
    
    self.x = self.eqPanelX + self.eqPanelW + spacing
    self.y = self.mainPanelY                        
    
    self.descPanelY = self.mainPanelY + mainGridH + 30 
    self.descPanelX = self.mainPanelX 
    self.descPanelW = totalContentW 
    self.descPanelH = 150 
    
    self.items = {}
    for i = 1, self.rows * self.cols do
        self.items[i] = nil
    end

    self.selectedRow = 1
    self.selectedCol = 1
    self.selectionMode = "main"

    self.equipped = {
        weapon = nil, artifact1 = nil, artifact2 = nil, artifact3 = nil,
        helmet = nil, chestplate = nil, leggins = nil, boots = nil
    }

    self.selectedEqRow = 1
    self.selectedEqCol = 1
    
    self.eqSlotMap = {
        [1] = { [1] = "weapon", [2] = "helmet" },
        [2] = { [1] = "artifact1", [2] = "chestplate" },
        [3] = { [1] = "artifact2", [2] = "leggins" },
        [4] = { [1] = "artifact3", [2] = "boots" },
    }
    
    self.eqSlotSize = 50 
    local eqPad = 68
    local startY = self.eqPanelY + 20
    local leftX = self.eqPanelX + 30 
    local rightX = self.eqPanelX + 240
    
    self.slotPositions = {
        weapon = {x=leftX, y=startY + 0 * eqPad},
        artifact1 = {x=leftX, y=startY + 1 * eqPad},
        artifact2 = {x=leftX, y=startY + 2 * eqPad},
        artifact3 = {x=leftX, y=startY + 3 * eqPad},
        helmet = {x=rightX, y=startY + 0 * eqPad},
        chestplate = {x=rightX, y=startY + 1 * eqPad},
        leggins = {x=rightX, y=startY + 2 * eqPad},
        boots = {x=rightX, y=startY + 3 * eqPad}
    }
    
    self.warriorImage = nil 
    if love.image and love.graphics and not self.warriorImage then
        local imgData = love.image.newImageData(WARRIOR_IMAGE_PATH)
        self.warriorImage = love.graphics.newImage(imgData)
    end
end

function inventory:toggle()
    self.isOpen = not self.isOpen
end

-- Funkcja sumująca bonusy dla Playera
function inventory:getBonuses()
    local totalBonuses = {
        hp = 0,
        mana = 0,
        stamina = 0,
        speed = 0,
        str = 0
    }

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

function inventory:getEqSlotBySelection()
    local row = self.selectedEqRow
    local col = self.selectedEqCol
    local map = self.eqSlotMap
    return map[row] and map[row][col]
end

function inventory:removeItemFromMain(item)
    for i = 1, self.rows * self.cols do
        if self.items[i] == item then
            self.items[i] = nil
            return
        end
    end
end

function inventory:getEquippedWeapon()
    return self.equipped.weapon
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
    
    if not slot then
        if itemType == "artifact" then
            print("Wszystkie sloty artefaktów zajęte.")
        else 
            print("Przedmiot nie pasuje do żadnego slotu.")
        end
        return
    end

    -- Zamiana przedmiotów (Swap)
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
            print("Ekwipunek pełny! Nie można podmienić.")
            return
        end
    end

    -- Zakładanie
    self.equipped[slot] = item
    item.equipped = true
    self:removeItemFromMain(item)

    -- Aktualizacja statystyk gracza
    if player and player.calculateStats then
        player:calculateStats()
    end

    print("Equipped " .. slot .. ": " .. item.data.name)
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
        print("Ekwipunek pełny! Przedmiot dodany na koniec.")
    end

    -- Aktualizacja statystyk gracza
    if player and player.calculateStats then
        player:calculateStats()
    end

    print("Unequipped " .. slotName)
end

-- === PRZYWRÓCONE FUNKCJE STEROWANIA ===

local function inventoryMainKeypressed(key)
    local maxRowMain = inventory.rows
    local maxColMain = inventory.cols

    if key == "right" then
        inventory.selectedCol = math.min(inventory.selectedCol + 1, maxColMain)

    elseif key == "left" then
        -- Przejście na panel EQ (lewo)
        if inventory.selectedCol == 1 then
            inventory.selectionMode = "equipped"
            inventory.selectedEqRow = math.min(inventory.selectedRow, 4) -- Dopasowanie wiersza
            inventory.selectedEqCol = 2 -- Celujemy w prawą kolumnę EQ
            return
        end
        inventory.selectedCol = math.max(inventory.selectedCol - 1, 1)

    elseif key == "down" then
        if inventory.selectedRow < maxRowMain then
            inventory.selectedRow = inventory.selectedRow + 1
        end

    elseif key == "up" then
        inventory.selectedRow = math.max(inventory.selectedRow - 1, 1)
    end

    if key == "return" then
        local index = (inventory.selectedRow - 1) * maxColMain + inventory.selectedCol
        local selectedItem = inventory.items[index]
        if selectedItem then
            inventory:equipItem(selectedItem)
        end
    end
end

local function inventoryEquippedKeypressed(key)
    local maxRowEq = 4
    local maxColEq = 2

    if key == "right" then
        -- Powrót do głównego EQ (prawo)
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
        if slotName then
            inventory:unequipItem(slotName)
        end
    end
end

-- === GŁÓWNA FUNKCJA KEYPRESSED ===

function inventory:keypressed(key)
    if not self.isOpen then return end
    local myKey = MapKey and MapKey(key) or key -- Zabezpieczenie jeśli MapKey nie istnieje
    
    if self.selectionMode == "main" then
        inventoryMainKeypressed(myKey)
    elseif self.selectionMode == "equipped" then
        inventoryEquippedKeypressed(myKey)
    end
end

-- === DRAW ===

function inventory:draw()
    if not self.isOpen then return end
    
    -- Główna siatka (Centrum)
    for row = 1, self.rows do
        for col = 1, self.cols do
            local index = (row - 1) * self.cols + col
            local item = self.items[index]
            local x = self.x + (col - 1) * (self.slotSize + self.padding)
            local y = self.y + (row - 1) * (self.slotSize + self.padding)

            love.graphics.setColor(0.2,0.2,0.2)
            love.graphics.rectangle("fill", x, y, self.slotSize, self.slotSize, 5,5)

            -- Podświetlenie wybranego slotu
            if self.selectionMode == "main" and row == self.selectedRow and col == self.selectedCol then
                love.graphics.setColor(1,1,0) -- Żółty
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x, y, self.slotSize, self.slotSize, 5,5)
                love.graphics.setLineWidth(1)
            end
            
            -- Rysowanie przedmiotów
            if item and item.data and item.data.image then
                love.graphics.setColor(1,1,1)
                local img = item.data.image
                local scale = math.min((self.slotSize-10)/img:getWidth(), (self.slotSize-10)/img:getHeight())
                love.graphics.draw(img, x+self.slotSize/2, y+self.slotSize/2, 0, scale, scale, img:getWidth()/2, img:getHeight()/2)
                
                -- Rysowanie ilości
                if item.amount and item.amount > 1 then
                    love.graphics.setFont(smallFont or love.graphics.getFont()) 
                    love.graphics.setColor(1,1,0)
                    love.graphics.print(tostring(item.amount), x+self.slotSize-15, y+self.slotSize-18)
                    love.graphics.setColor(1,1,1)
                end
            end
        end
    end

    -- Panel opisu (Dół)
    local selectedItem = nil
    if self.selectionMode == "main" then
        local selectedIndex = (self.selectedRow-1)*self.cols + self.selectedCol
        selectedItem = self.items[selectedIndex]
    elseif self.selectionMode == "equipped" then
        local slotName = self:getEqSlotBySelection()
        if slotName then selectedItem = self.equipped[slotName] end
    end

    local panelX = self.descPanelX 
    local panelY = self.descPanelY 
    local panelWidth = self.descPanelW 
    local panelHeight = self.descPanelH 
    
    love.graphics.setColor(0.1,0.1,0.1,0.8)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 10,10)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 10,10)

    love.graphics.setFont(love.graphics.getFont()) 
    if selectedItem and selectedItem.data then
        local amountText = selectedItem.amount and " x"..selectedItem.amount or ""
        love.graphics.printf("Item: "..selectedItem.data.name..amountText, panelX+10, panelY+15, panelWidth-20, "left")
        love.graphics.printf("Description:\n"..selectedItem.data.desc, panelX+10, panelY+45, panelWidth-20, "left")
        local statusText = selectedItem.equipped and "Equipped" or "Unequipped"
        love.graphics.printf("Status: "..statusText, panelX+10, panelY+panelHeight-25, panelWidth-20, "left")
    else
        love.graphics.printf("Empty slot", panelX+10, panelY+15, panelWidth-20, "left")
    end

    -- Panel ekwipunku (EQ) (Lewa strona)
    local eqPanelX = self.eqPanelX
    local eqPanelY = self.eqPanelY
    local eqPanelW = self.eqPanelW
    local eqPanelH = self.eqPanelH
    
    love.graphics.setColor(0.1,0.1,0.1,0.8)
    love.graphics.rectangle("fill", eqPanelX, eqPanelY, eqPanelW, eqPanelH, 10,10)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", eqPanelX, eqPanelY, eqPanelW, eqPanelH, 10,10)
    
    
    -- Rysowanie obrazka warriora
    if self.warriorImage then
        local img = self.warriorImage
        local imgX = eqPanelX + eqPanelW / 2 
        local imgY = eqPanelY + 135
        local scale = 0.25
        love.graphics.setColor(1,1,1) 
        love.graphics.draw(img, imgX, imgY, 0, scale, scale, img:getWidth()/2, img:getHeight()/2)
    end
    
    -- Rysowanie slotów ekwipunku
    local eqSlotSelectionMap = self.eqSlotMap
    local currentEqSelection = self:getEqSlotBySelection()
    
    love.graphics.setFont(smallFont or love.graphics.getFont()) 

    -- Iteracja przez logiczne wiersze i kolumny
    for row = 1, 4 do
        for col = 1, 2 do
            local name = eqSlotSelectionMap[row][col]
            local pos = self.slotPositions[name]
            local slotX = pos.x
            local slotY = pos.y
            local slotW = self.eqSlotSize
            local slotH = self.eqSlotSize

            -- Otoczka (tło)
            love.graphics.setColor(0.2,0.2,0.2)
            love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 5,5)
            
            -- Rysowanie nazwy slota
            love.graphics.setColor(1,1,1)
            love.graphics.printf(name:upper(), slotX-25, slotY-15, 100, "center", 0,1,1)

            local item = self.equipped[name]
            if item and item.data and item.data.image then
                local img = item.data.image
                love.graphics.setColor(1,1,1) 
                love.graphics.draw(img, slotX+slotW/2, slotY+slotH/2, 0, 0.6, 0.6, img:getWidth()/2, img:getHeight()/2)
            end

            -- Ramka/Podświetlenie
            if self.selectionMode == "equipped" and currentEqSelection == name then
                love.graphics.setColor(1,1,0) -- Żółty dla podświetlenia
                love.graphics.setLineWidth(3)
            else
                love.graphics.setColor(1,1,1) -- Biały domyślny
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 5,5)
        end
    end

    love.graphics.setLineWidth(1) 
    love.graphics.setColor(1, 1, 1) -- reset koloru
end

return inventory