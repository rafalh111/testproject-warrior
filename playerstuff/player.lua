local player = {}

-- Bazowe wartości (nie nadpisywane przez bonusy bezpośrednio)
player.baseDmg = 10
player.baseMaxHp = 64
player.baseMaxStamina = 128
player.baseMaxMana = 128
player.baseSpeed = 350

local items = require("playerstuff.items")
local bullets = require("combat.bullets")
local leveling = require("playerstuff.leveling")

-- USUNIĘTO: local inventory = _G.inventory -- Zmienna będzie pobierana bezpośrednio z _G.inventory

function player:load(world, anim8)
    -- Wymiary gracza / hitbox
    self.width = 50
    self.height = 100

    -- FIZYKA I KOLIZJE
    self.collider = world:newRectangleCollider(400, 250, self.width, self.height)
    self.collider:setFixedRotation(true)

    self.x = 400
    self.y = 300
    self.speed = self.baseSpeed

    -- SPRITE / ANIMACJE
    self.spritesheet = love.graphics.newImage("sprites/player-sheet.png")
    self.grid = anim8.newGrid(12, 18, self.spritesheet:getWidth(), self.spritesheet:getHeight())

    self.animations = {
        down = anim8.newAnimation(self.grid('1-4', 1), 0.2),
        up = anim8.newAnimation(self.grid('1-4', 4), 0.2),
        right = anim8.newAnimation(self.grid('1-4', 3), 0.2),
        left = anim8.newAnimation(self.grid('1-4', 2), 0.2)
    }
    self.anim = self.animations.down

    -- SKOK/DASH
    self.jump = false
    self.jumpSpeed = -250
    self.gravity = 700
    self.vy = 0
    self.jumpHeight = 0
    self.directionX = 0
    self.directionY = 0

    -- COOLDOWN SKOKU
    self.canJump = true
    self.jumpCooldown = 0.5
    self.jumpTimer = 0

    -- STAMINA (wartości aktualne inicjalizowane z bazowych)
    self.maxStamina = self.baseMaxStamina
    self.stamina = self.maxStamina
    self.staminaRegen = 20
    self.staminaDrain = 30

    -- ŻYCIE
    self.maxHp = self.baseMaxHp
    self.hp = self.maxHp
    self.hpRegen = 2

    -- MANA
    self.maxMana = self.baseMaxMana
    self.mana = self.baseMaxMana
    self.manaRegen = 10

    -- AMUNICJA I RELOAD
    self.reloading = false
    self.reloadTime = 3
    self.reloadTimer = 0

    self.ammo = self.ammo or 322
    self.extraAmmo = self.extraAmmo or 9999
    self.shotgunAmmo = self.shotgunAmmo or 888
    self.extraShotgunAmmo = self.extraShotgunAmmo or 32

    -- pola pomocnicze do statów
    self.str = self.baseDmg
    self.damage = self.baseDmg
    
    -- === INICJALIZACJA PUNKTÓW LEVELINGU ===
    self.baseMaxHpPoints = self.baseMaxHpPoints or 0
    self.baseDamagePoints = self.baseDamagePoints or 0
    self.baseMaxStaminaPoints = self.baseMaxStaminaPoints or 0
    self.baseMaxManaPoints = self.baseMaxManaPoints or 0
    self.baseSpeedPoints = self.baseSpeedPoints or 0

    -- ensure calculateStats exists
    function self:calculateStats()
        -- Reset do bazowych wartości
        self.str = self.baseDmg
        self.maxHp = self.baseMaxHp
        self.maxStamina = self.baseMaxStamina
        self.maxMana = self.baseMaxMana
        self.speed = self.baseSpeed

        -- Pobierz sumaryczne bonusy z inventory, jeśli dostępne
        local inventoryBonuses = {}
        if _G.inventory and _G.inventory.getBonuses then
            -- Użycie _G.inventory i dwukropka
            inventoryBonuses = _G.inventory:getBonuses() or {} 
        end
        
        -- === OBLICZANIE CAŁKOWITYCH BONUSÓW (Leveling Points + Inventory %) ===
        
        -- Leveling Points (z player.lua) konwertowane na procenty (0.01 za każdy punkt)
        local levelingBonusHp = (self.baseMaxHpPoints or 0) / 100
        local levelingBonusStr = (self.baseDamagePoints or 0) / 100
        local levelingBonusStamina = (self.baseMaxStaminaPoints or 0) / 100
        local levelingBonusMana = (self.baseMaxManaPoints or 0) / 100
        local levelingBonusSpeed = (self.baseSpeedPoints or 0) / 100
        
        -- Sumowanie bonusów z Leveling i Inventory
        local totalHpBonus = levelingBonusHp + (inventoryBonuses.hp or 0)
        local totalStrBonus = levelingBonusStr + (inventoryBonuses.str or 0)
        local totalStaminaBonus = levelingBonusStamina + (inventoryBonuses.stamina or 0)
        local totalManaBonus = levelingBonusMana + (inventoryBonuses.mana or 0)
        local totalSpeedBonus = levelingBonusSpeed + (inventoryBonuses.speed or 0)
        
        -- === APLIKACJA WYNIKOWYCH BONUSÓW ===

        -- str traktujemy jako mnożnik do bazowego dmg
        self.str = self.baseDmg * (1 + totalStrBonus)
        self.maxHp = self.baseMaxHp * (1 + totalHpBonus)
        self.maxStamina = self.baseMaxStamina * (1 + totalStaminaBonus)
        self.maxMana = self.baseMaxMana * (1 + totalManaBonus)
        -- speed to % do podstawowej prędkości poruszania
        self.speed = self.baseSpeed * (1 + totalSpeedBonus)

        -- Zaktualizuj current damage i upewnij się, że aktualne HP / stamina / mana nie przekraczają maksów
        self.damage = self.str
        self.hp = math.min(self.hp, self.maxHp)
        self.stamina = math.min(self.stamina, self.maxStamina)
        self.mana = math.min(self.mana, self.maxMana)

        -- Zaktualizuj currentAmmo pola na podstawie broni w inventory (jeśli jest)
        if _G.inventory and _G.inventory.getEquippedWeapon then
            -- Użycie _G.inventory i dwukropka
            local w = _G.inventory:getEquippedWeapon() 
            if w and w.data then
                if w.data.name == "Shotgun" or (w.data.type and w.data.type == "weapon" and w.data.name == "Shotgun") then
                    self.currentAmmo = self.shotgunAmmo
                    self.currentExtraAmmo = self.extraShotgunAmmo
                else
                    self.currentAmmo = self.ammo
                    self.currentExtraAmmo = self.extraAmmo
                end
            else
                -- brak broni
                self.currentAmmo = 0
                self.currentExtraAmmo = 0
            end
        end
    end
end

function player:update(dt)
    --BLOKADA RUCHU GRACZA
    if leveling.levelUpAvailable then
        self.collider:setLinearVelocity(0, 0)
        self.anim:update(dt)
        return
    end
    
    -- Używamy self.speed z calculateStats
    local currentSpeed = self.speed 
    
    local vx, vy = 0, 0
    local isMoving = false

    -- === DYNAMICZNE STEROWANIE KLAWISZAMI ===
    local UpKey = GetBoundKey("Up") or "w"
    local DownKey = GetBoundKey("Down") or "s"
    local LeftKey = GetBoundKey("Left") or "a"
    local RightKey = GetBoundKey("Right") or "d"
    local SprintKey = GetBoundKey("Sprint") or "lshift"

    if love.keyboard.isDown(RightKey) then vx = vx + 1; self.anim = self.animations.right; isMoving = true end
    if love.keyboard.isDown(LeftKey) then vx = vx - 1; self.anim = self.animations.left; isMoving = true end
    if love.keyboard.isDown(UpKey) then vy = vy - 1; self.anim = self.animations.up; isMoving = true end
    if love.keyboard.isDown(DownKey) then vy = vy + 1; self.anim = self.animations.down; isMoving = true end

    local len = math.sqrt(vx*vx + vy*vy)
    if len > 0 then vx = vx / len; vy = vy / len end

    -- Sprint
    local isSprinting = love.keyboard.isDown(SprintKey) and self.stamina > 0
    
    local finalSpeed = currentSpeed -- domyślna prędkość (z calculateStats)
    
    if isSprinting then
        -- Sprint: 650 to bazowa prędkość sprintu
        local sprintMultiplier = 650 / self.baseSpeed
        finalSpeed = currentSpeed * sprintMultiplier
        self.stamina = math.max(0, self.stamina - self.staminaDrain * dt)
    else
        self.stamina = math.min(self.maxStamina, self.stamina + self.staminaRegen * dt)
    end
    
    if not self.canJump then
        self.jumpTimer = self.jumpTimer - dt
        if self.jumpTimer <= 0 then
            self.canJump = true
        end
    end

    -- SKOK / DASH
    if self.jump then
        self.vy = self.vy + self.gravity * dt
        self.jumpHeight = self.jumpHeight + self.vy * dt
        local nx = self.collider:getX() + self.directionX * finalSpeed * 0.05 * dt
        self.collider:setX(nx)
        if self.jumpHeight >= 0 then
            self.jumpHeight = 0
            self.vy = 0
            self.jump = false
        end
    else
        self.collider:setLinearVelocity(vx * finalSpeed, vy * finalSpeed)
    end

    -- regeneracja many
    self.mana = math.min(self.maxMana, self.mana + self.manaRegen * dt)

    -- obsługa reload
    if self.reloading then
        self.reloadTimer = self.reloadTimer - dt
        if self.reloadTimer <= 0 then
            self.reloading = false
            -- Użycie _G.inventory i dwukropka
            local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()
            if weaponItem and weaponItem.data then
                if weaponItem.data.name == "Shotgun" then
                    local needed = 8 - (self.shotgunAmmo or 0)
                    if (self.extraShotgunAmmo or 0) >= needed then
                        self.shotgunAmmo = 8
                        self.extraShotgunAmmo = self.extraShotgunAmmo - needed
                    else
                        self.shotgunAmmo = (self.shotgunAmmo or 0) + (self.extraShotgunAmmo or 0)
                        self.extraShotgunAmmo = 0
                    end
                else
                    local needed = 32 - (self.ammo or 0)
                    if (self.extraAmmo or 0) >= needed then
                        self.ammo = 32
                        self.extraAmmo = self.extraAmmo - needed
                    else
                        self.ammo = (self.ammo or 0) + (self.extraAmmo or 0)
                        self.extraAmmo = 0
                    end
                end
            end
        end
    end

    self.x = self.collider:getX()
    self.y = self.collider:getY()
    self.anim:update(dt)

    if not isMoving then
        self.anim:gotoFrame(2)
    end

    -- przelicz staty z inventory (bonuses) ORAZ LEVELINGU
    if self.calculateStats then
        self:calculateStats()
    end
end

function player:keypressed(key)
    local mappedKey = MapKey(key)

    -- BLOKADA AKCJI KLAWISZOWYCH
    if leveling.levelUpAvailable then return end
    
    if mappedKey == "jump" or key == "space" then
        if not self.jump and self.canJump then
            local vx, vy = 0, 0
            local UpKey = GetBoundKey("Up") or "w"
            local DownKey = GetBoundKey("Down") or "s"
            local LeftKey = GetBoundKey("Left") or "a"
            local RightKey = GetBoundKey("Right") or "d"

            if love.keyboard.isDown(UpKey) then vy = -1 end
            if love.keyboard.isDown(DownKey) then vy = 1 end
            if love.keyboard.isDown(LeftKey) then vx = -1 end
            if love.keyboard.isDown(RightKey) then vx = 1 end

            self.jump = true
            self.vy = self.jumpSpeed
            self.directionX = vx
            self.directionY = vy
            self.jumpHeight = -0.0001
            self.canJump = false
            self.jumpTimer = self.jumpCooldown
        end
    end

    if mappedKey == "reload" or key == "r" then
        -- Użycie _G.inventory i dwukropka
        local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()
        if weaponItem and weaponItem.data then
            if weaponItem.data.name == "Shotgun" then
                if not self.reloading and (self.shotgunAmmo or 0) < 8 and (self.extraShotgunAmmo or 0) > 0 then
                    self.reloading = true
                    self.reloadTimer = self.reloadTime
                end
            else
                if not self.reloading and (self.ammo or 0) < 32 and (self.extraAmmo or 0) > 0 then
                    self.reloading = true
                    self.reloadTimer = self.reloadTime
                end
            end
        end
    end
end

function player:draw()
    local distance = 40
    -- Wiersz 326: Użycie _G.inventory i dwukropka
    local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()

    local function drawPlayerAndWeapon()
        if weaponItem and weaponItem.data and weaponItem.data.image then
            local weaponImg = weaponItem.data.image
            local wx, wy = self.x, self.y + self.jumpHeight
            local rotation = 0
            local sx, sy = 0.5, 0.5
            local drawWeaponFirst = false

            if self.anim == self.animations.up then
                wy = wy + distance / 8
                rotation = -math.pi*2
                drawWeaponFirst = true
            elseif self.anim == self.animations.down then
                wy = wy + distance - 35
                rotation = math.pi*2
            elseif self.anim == self.animations.left then
                wx = wx - distance / 3
                wy = wy + 10
                rotation = math.pi/32
            elseif self.anim == self.animations.right then
                wx = wx + distance / 3
                wy = wy + 10
                rotation = -math.pi/32
                sx = -0.5
            end

            local function drawWeapon()
                love.graphics.draw(
                    weaponImg,
                    wx,
                    wy,
                    rotation,
                    sx, sy,
                    weaponImg:getWidth()/2,
                    weaponImg:getHeight()/2
                )
            end

            if drawWeaponFirst then
                drawWeapon()
                self.anim:draw(self.spritesheet, self.x, self.y + self.jumpHeight, nil, 6, 6, 6, 9)
            else
                self.anim:draw(self.spritesheet, self.x, self.y + self.jumpHeight, nil, 6, 6, 6, 9)
                drawWeapon()
            end
        else
            self.anim:draw(self.spritesheet, self.x, self.y + self.jumpHeight, nil, 6, 6, 6, 9)
        end
    end

    drawPlayerAndWeapon()

    -- HUD ammo
    if weaponItem and weaponItem.data and (weaponItem.data.name == "AssaultRifle" or weaponItem.data.name == "Shotgun") then
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setColor(1,1,1)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

        local currentAmmo, maxAmmo = 0, 0
        if weaponItem.data.name == "Shotgun" then
            currentAmmo = self.shotgunAmmo or 0
            maxAmmo = self.extraShotgunAmmo or 0
        else
            currentAmmo = self.ammo or 0
            maxAmmo = self.extraAmmo or 0
        end

        if self.reloading then
            love.graphics.printf("RELOADING...", 0, h-50, w-100, "center", 0, 2, 2)
        else
            love.graphics.printf("Ammo: "..currentAmmo.."/"..maxAmmo, 0, h-50, w-100, "center", 0, 2, 2)
        end
        love.graphics.pop()
    end

    -- Pasek staminy
    if self.stamina < self.maxStamina then
        local barWidth = 50
        local barHeight = 6
        local barOffsetY = 50
        local barX = self.x - barWidth / 2
        local barY = self.y + barOffsetY + self.jumpHeight

        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 3, 3)

        local staminaWidth = (self.stamina / self.maxStamina) * barWidth
        love.graphics.setColor(0.1, 0.8, 0.2)
        love.graphics.rectangle("fill", barX, barY, staminaWidth, barHeight, 3, 3)

        love.graphics.setColor(1,1,1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 3, 3)
    end

    -- Nick gracza
    if self.name then
        love.graphics.setColor(1,1,1)
        love.graphics.printf(self.name, self.x-50, self.y-70+self.jumpHeight, 100, "center")
    end

    -- DEBUG hitbox
    if debugMode and self.collider then
        love.graphics.setColor(1,0,0,0.5)
        local cx, cy = self.collider:getPosition()
        love.graphics.rectangle("line", cx-self.width/2, cy-self.height/2+self.jumpHeight, self.width, self.height)
        love.graphics.setColor(1,1,1)
    end
end

function player:mousepressed(mx, my, button)
    --  BLOKADA AKCJI MYSZY
    if leveling.levelUpAvailable then 
        return 
    end

    --Zabezpieczenie przed strzelaniem w trybie menu/ładowania
    if _G.gameState ~= "playing" then return end

    if button ~= 1 then return end

    -- Użycie _G.inventory i dwukropka
    local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()
    if not (weaponItem and weaponItem.data) then return end
    if weaponItem.data.name ~= "AssaultRifle" and weaponItem.data.name ~= "Shotgun" then return end
    if self.reloading then return end

    local currentAmmo = weaponItem.data.name == "Shotgun" and self.shotgunAmmo or self.ammo
    if (currentAmmo or 0) <= 0 then return end

    local wx, wy = self.x, self.y + self.jumpHeight
    local distance = 40

    if self.anim == self.animations.up then
        wy = wy - distance
    elseif self.anim == self.animations.down then
        wy = wy + distance
    elseif self.anim == self.animations.left then
        wx = wx - distance
    elseif self.anim == self.animations.right then
        wx = wx + distance
    end


    local worldX, worldY = cam:worldCoords(mx, my)
    local dx, dy = worldX - wx, worldY - wy
    local len = math.sqrt(dx*dx + dy*dy)
        if len > 0 then
            dx = dx / len
            dy = dy / len
        end

    local isShotgunBullet = (weaponItem.data.name == "Shotgun")

        if isShotgunBullet then

    local pellets = 4 -- ilość ammo shotguna
    local spreadAngle = math.pi / 18 -- Kąt rozrzutu (10 stopni w radianach)
    local currentAngle = math.atan2(dy, dx) -- Kierunek strzału

    for i = 1, pellets do
        -- Oblicza rozrzut: od -spreadAngle/2 do +spreadAngle/2
        local offset = ((i - 1) / (pellets - 1) - 0.5) * spreadAngle
        local angle = currentAngle + offset

        -- Przelicza kąt z powrotem na wektor kierunku (dx, dy)
        local newDx = math.cos(angle)
        local newDy = math.sin(angle)

        bullets:spawn(wx, wy, newDx, newDy, self.damage, true)
    end

        -- Zużycie amunicji
            self.shotgunAmmo = (self.shotgunAmmo or 0) - 4
    else

        bullets:spawn(wx, wy, dx, dy, self.damage, isShotgunBullet)
        self.ammo = (self.ammo or 0) - 1
    end
end

return player