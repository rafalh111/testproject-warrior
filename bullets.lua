local bullets = {}

local world = nil
local list = {}
local nextBulletID = 1

bullets.list = list

local enemies = require("enemies")
local player = require("player")
local walls = {} 

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function bullets:load()
    self.list = list
    self.speed = 1500 -- Bazowa prędkość pocisków (np. karabin)
    self.shotgunSpeed = 900 -- << ZMIANA: Nowa prędkość dla pocisków strzelby
    self.radius = 5
end

function bullets:init(windfieldWorld)
    world = windfieldWorld
end

function bullets:setWalls(wallList)
    walls = wallList
end

function bullets:spawn(x, y, dx, dy, damage, isShotgun)
    -- << ZMIANA: Wybór prędkości w zależności od typu pocisku
    local currentSpeed = isShotgun and self.shotgunSpeed or self.speed
    
    local bullet = {
        x = x,
        y = y,
        velX = dx * currentSpeed, -- Użycie wybranej prędkości
        velY = dy * currentSpeed, -- Użycie wybranej prędkości
        life = 2,
        damage = damage or player.damage,
        isDead = false,
        id = nextBulletID,
        isShotgun = isShotgun or false,
        hasBounced = false,
        collider = world:newCircleCollider(x, y, self.radius)
    }
    bullet.collider:setCollisionClass('Bullet')
    bullet.collider:setSensor(true)
    nextBulletID = nextBulletID + 1
    table.insert(list, bullet)
end

function bullets:remove(bullet)
    if bullet then
        bullet.isDead = true
        if bullet.collider then bullet.collider:destroy() end
    end
end

local function bulletHitsRect(b, e)
    local closestX = math.max(e.x, math.min(b.x, e.x + e.w))
    local closestY = math.max(e.y, math.min(b.y, e.y + e.h))
    local dist = distance(b.x, b.y, closestX, closestY)
    return dist < bullets.radius
end

function bullets:update(dt)
    for i = #list, 1, -1 do
        local b = list[i]

        b.life = b.life - dt
        
        local newX = b.x + b.velX * dt
        local newY = b.y + b.velY * dt
        
        local hit = false

        for _, enemy in ipairs(enemies.list or {}) do
            if bulletHitsRect({x = newX, y = newY, radius = bullets.radius}, enemy) then
                enemies:takeDamage(enemy, b.damage)
                hit = true
                break
            end
        end

        if not hit then
            for _, wall in ipairs(walls) do
                if wall and wall.x then
                    local l = wall.x
                    local t = wall.y
                    local r = wall.x + wall.w
                    local btm = wall.y + wall.h

                    local insideWall =
                        (newX >= l and newX <= r and newY >= t and newY <= btm)

                    local hitX =
                        (newX + bullets.radius > l and b.x - bullets.radius <= l) or
                        (newX - bullets.radius < r and b.x + bullets.radius >= r)

                    local hitY =
                        (newY + bullets.radius > t and b.y - bullets.radius <= t) or
                        (newY - bullets.radius < btm and b.y + bullets.radius >= btm)

                    if insideWall and (hitX or hitY) then
                        
                        if b.isShotgun then
                            if not b.hasBounced then
                                if hitX then b.velX = -b.velX end
                                if hitY then b.velY = -b.velY end
                                b.hasBounced = true
                                b.life = b.life * 0.8
                                newX = b.x + b.velX * dt * 0.01
                                newY = b.y + b.velY * dt * 0.01
                            else
                                hit = true
                            end
                        else
                            hit = true
                        end

                        if hit then break end
                    end
                end
            end
        end

        b.x = newX
        b.y = newY
        if b.collider then b.collider:setPosition(b.x, b.y) end

        if hit or b.life <= 0 or b.isDead then
            self:remove(b)
            table.remove(list, i)
        end
    end
end

function bullets:draw()
    for _, b in ipairs(list) do
        if b.isShotgun then
            love.graphics.setColor(0, 1, 1)
        else
            love.graphics.setColor(1, 1, 0)
        end
        love.graphics.circle("fill", b.x, b.y, self.radius)
    end
    love.graphics.setColor(1, 1, 1)
end

return bullets