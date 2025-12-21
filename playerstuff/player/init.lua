local player = {}

-- Moduły (powinny znajdować się w folderze playerstuff/player/)
local Stats = require("playerstuff.player.stats")
local Movement = require("playerstuff.player.movement")
local Combat = require("playerstuff.player.combat")

local items = require("playerstuff.items")
local leveling = require("playerstuff.leveling")

function player:load(world, anim8)
    -- Wymiary i Fizyka (Inicjalizacja obiektów)
    self.width = 50
    self.height = 100
    self.collider = world:newRectangleCollider(400, 250, self.width, self.height)
    self.collider:setFixedRotation(true)
    self.x, self.y = 400, 300

    -- Sprite / Animacje
    self.spritesheet = love.graphics.newImage("sprites/player-sheet.png")
    self.grid = anim8.newGrid(12, 18, self.spritesheet:getWidth(), self.spritesheet:getHeight())
    self.animations = {
        down = anim8.newAnimation(self.grid('1-4', 1), 0.2),
        up = anim8.newAnimation(self.grid('1-4', 4), 0.2),
        right = anim8.newAnimation(self.grid('1-4', 3), 0.2),
        left = anim8.newAnimation(self.grid('1-4', 2), 0.2)
    }
    self.anim = self.animations.down

    -- Inicjalizacja modułów
    Stats:init(self)
    Movement:init(self)
    Combat:init(self)
    
    -- Pierwsze przeliczenie statów
    Stats:calculate(self)
end

function player:update(dt)
    -- === POPRAWKA: Blokada tylko gdy OKNO jest OTWARTE ===
    if leveling.isOpen then
        self.collider:setLinearVelocity(0, 0)
        self.anim:update(dt)
        return
    end

    -- Delegujemy logikę do modułów
    Movement:update(self, dt)
    Combat:update(self, dt)
    Stats:updateRegen(self, dt)

    -- Synchronizacja pozycji z fizyką
    self.x = self.collider:getX()
    self.y = self.collider:getY()
    self.anim:update(dt)
    
    Stats:calculate(self) -- Przeliczanie statów (bonusy z ekwipunku)
end

function player:keypressed(key)
    -- === POPRAWKA: Blokada klawiszy tylko gdy menu otwarte ===
    if leveling.isOpen then return end
    
    local mappedKey = MapKey(key)

    if mappedKey == "jump" or key == "space" then
        Movement:tryJump(self)
    end

    if mappedKey == "reload" or key == "r" then
        Combat:tryReload(self)
    end
end

function player:mousepressed(mx, my, button)
    -- === POPRAWKA: Blokada strzelania tylko gdy menu otwarte ===
    if leveling.isOpen then return end
    if _G.Game.state ~= "playing" then return end
    if button ~= 1 then return end
    
    Combat:shoot(self, mx, my, cam) 
end

function player:draw()
    local distance = 40
    local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()

    -- === 1. RYSOWANIE GRACZA I BRONI ===
    local function drawPlayerAndWeapon()
        if not self.anim then self.anim = self.animations.down end

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
                    wx, wy,
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

    -- === 2. HUD AMUNICJI ===
    if weaponItem and weaponItem.data and (weaponItem.data.name == "AssaultRifle" or weaponItem.data.name == "Shotgun") then
        love.graphics.push()
        love.graphics.origin() 
        love.graphics.setColor(1,1,1)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

        local currentAmmo = self.currentAmmo or 0
        local maxAmmo = self.currentExtraAmmo or 0

        if self.reloading then
            love.graphics.printf("RELOADING...", 0, h-50, w-100, "center", 0, 2, 2)
        else
            love.graphics.printf("Ammo: "..currentAmmo.."/"..maxAmmo, 0, h-50, w-100, "center", 0, 2, 2)
        end
        love.graphics.pop()
    end
    
    -- === 3. PASKO STAMINY ===
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
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 3, 3)
    end

    -- === 4. NICK GRACZA ===
    if self.name then
        love.graphics.setColor(1,1,1)
        love.graphics.printf(self.name, self.x-50, self.y-70+self.jumpHeight, 100, "center")
    end
end

return player