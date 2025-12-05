local pickup = {}

-- pozycja gracza
local function getPlayerPos(player)
    if not player then return nil, nil end
    if player.collider and player.collider.getPosition then
        local x, y = player.collider:getPosition()
        return x, y
    elseif player.x and player.y then
        return player.x, player.y
    else
        return nil, nil
    end
end

-- bounding box
local function getPlayerBox(player)
    local px, py = getPlayerPos(player)
    if not px then return nil end

    -- wymiary gracza
    local w = player.width or player.w or player.sizeX or 32
    local h = player.height or player.h or player.sizeY or 48

    -- jeśli collider istnieje
    local left = px - w/2
    local top = py - h/2
    return { x = left, y = top, w = w, h = h }
end

-- AABB sprawdzenie kolizji prostokąt-przecięcie
local function rectsOverlap(a, b)
    return not (a.x + a.w < b.x or b.x + b.w < a.x or a.y + a.h < b.y or b.y + b.h < a.y)
end

function pickup.checkCollision(player, item)
    if not player or not item then return false end

    -- item width/height
    if not item.width or not item.height then
        if item.data and item.data.image then
            item.width = item.data.image:getWidth() * (item.scale or 1)
            item.height = item.data.image:getHeight() * (item.scale or 1)
        else
            item.width = item.width or 16
            item.height = item.height or 16
        end
    end

    local playerBox = getPlayerBox(player)
    if not playerBox then
        -- fallback do distance
        local px, py = getPlayerPos(player)
        if not px then return false end
        local ix = item.x + (item.width or 0)/2
        local iy = item.y + (item.height or 0)/2
        local dx = px - ix
        local dy = py - iy
        local dist = math.sqrt(dx*dx + dy*dy)
        -- threshold
        return dist < 48
    end

    -- item box (item.x,y to lewy-górny jak w Tiled)
    local itemBox = { x = item.x, y = item.y, w = item.width, h = item.height }

    -- (zasięg podnoszenia)
    local pickupMargin = 8
    playerBox.x = playerBox.x - pickupMargin
    playerBox.y = playerBox.y - pickupMargin
    playerBox.w = playerBox.w + pickupMargin * 2
    playerBox.h = playerBox.h + pickupMargin * 2

    return rectsOverlap(playerBox, itemBox)
end

-- Dodawanie itemu do inventory (12 slotów) z obsługą stackowania
function pickup.addItemToInventory(inventory, itemData)
    if not itemData or not inventory then return false end

    -- sprawdzanie stackowania dla Coin
    local isStackable = itemData.name == "Coin" -- tu możesz dodać inne stackowalne itemy
    if isStackable then
        for i = 1, 12 do
            local slot = inventory.items[i]
            if slot and slot.itemType == itemData.name then
                -- jeśli już jest, zwiększamy ilość
                slot.amount = (slot.amount or 1) + 1
                return true
            end
        end
    end

    -- jeśli nie stackujemy lub brak istniejącego stacka, dodajemy nowy slot
    for i = 1, 12 do
        if inventory.items[i] == nil then
            inventory.items[i] = {
                itemType = itemData.name or itemData.itemType or "item",
                data = itemData,
                equipped = false,
                amount = isStackable and 1 or nil
            }
            return true
        end
    end

    return false
end

function pickup.update(player, inventory, items, itemsData)
    if not items then return end

    for i = #items, 1, -1 do
        local item = items[i]
        if not item then goto continue end

        -- domyślne wymiary
        if item.width == nil or item.height == nil then
            if item.data and item.data.image then
                local scale = item.scale or 1
                item.width = (item.data.image:getWidth() or 16) * scale
                item.height = (item.data.image:getHeight() or 16) * scale
            else
                item.width = item.width or 16
                item.height = item.height or 16
            end
        end

        if item.canPickup == nil then
            item.canPickup = true
        end

        if not item.collected then
            local colliding = pickup.checkCollision(player, item)

            if colliding and item.canPickup and item.data then
                if pickup.addItemToInventory(inventory, item.data) then
                    item.collected = true
                    print("Picked up:", item.data.name or "item")
                else
                    item.canPickup = false
                    print("Inventory full, cannot pick up:", item.data.name or "item")
                end
            elseif not colliding then
                -- reset flagi, jeśli gracz oddalił się
                item.canPickup = true
            end
        end

        ::continue::
    end
end

return pickup
