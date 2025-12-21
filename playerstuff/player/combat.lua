local Combat = {}

function Combat:init(player)
    player.reloading = false
    player.reloadTime = 3
    player.reloadTimer = 0

    player.ammo = player.ammo or 32
    player.extraAmmo = player.extraAmmo or 9999
    player.shotgunAmmo = player.shotgunAmmo or 12
    player.extraShotgunAmmo = player.extraShotgunAmmo or 9999
    
    player.currentAmmo = 0
    player.currentExtraAmmo = 0
end

function Combat:update(player, dt)
    -- Obsługa timera przeładowania
    if player.reloading then
        player.reloadTimer = player.reloadTimer - dt
        if player.reloadTimer <= 0 then
            player.reloading = false
            self:finishReload(player)
        end
    end
    
    -- Aktualizacja info o ammo dla UI (currentAmmo)
    local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()
    if weaponItem and weaponItem.data then
        if weaponItem.data.name == "Shotgun" then
            player.currentAmmo = player.shotgunAmmo
            player.currentExtraAmmo = player.extraShotgunAmmo
        else
            player.currentAmmo = player.ammo
            player.currentExtraAmmo = player.extraAmmo
        end
    else
        player.currentAmmo = 0
        player.currentExtraAmmo = 0
    end
end

function Combat:finishReload(player)
    local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()
    if not (weaponItem and weaponItem.data) then return end

    if weaponItem.data.name == "Shotgun" then
        local needed = 4 - (player.shotgunAmmo or 0)
        if (player.extraShotgunAmmo or 0) >= needed then
            player.shotgunAmmo = 12
            player.extraShotgunAmmo = player.extraShotgunAmmo - needed
        else
            player.shotgunAmmo = (player.shotgunAmmo or 0) + (player.extraShotgunAmmo or 0)
            player.extraShotgunAmmo = 0
        end
    else
        local needed = 32 - (player.ammo or 0)
        if (player.extraAmmo or 0) >= needed then
            player.ammo = 32
            player.extraAmmo = player.extraAmmo - needed
        else
            player.ammo = (player.ammo or 0) + (player.extraAmmo or 0)
            player.extraAmmo = 0
        end
    end
end

function Combat:tryReload(player)
    local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()
    if not (weaponItem and weaponItem.data) then return end

    if weaponItem.data.name == "Shotgun" then
        if not player.reloading and (player.shotgunAmmo or 0) < 8 and (player.extraShotgunAmmo or 0) > 0 then
            player.reloading = true
            player.reloadTimer = player.reloadTime
        end
    else
        if not player.reloading and (player.ammo or 0) < 32 and (player.extraAmmo or 0) > 0 then
            player.reloading = true
            player.reloadTimer = player.reloadTime
        end
    end
end

function Combat:shoot(player, mx, my, cam)
    if player.reloading then return end

    local weaponItem = _G.inventory and _G.inventory.getEquippedWeapon and _G.inventory:getEquippedWeapon()
    if not (weaponItem and weaponItem.data) then return end
    if weaponItem.data.name ~= "AssaultRifle" and weaponItem.data.name ~= "Shotgun" then return end

    local currentAmmo = (weaponItem.data.name == "Shotgun") and player.shotgunAmmo or player.ammo
    if (currentAmmo or 0) <= 0 then return end

    -- Oblicz pozycję startową pocisku
    local wx, wy = player.x, player.y + player.jumpHeight
    local distance = 40
    if player.anim == player.animations.up then wy = wy - distance
    elseif player.anim == player.animations.down then wy = wy + distance
    elseif player.anim == player.animations.left then wx = wx - distance
    elseif player.anim == player.animations.right then wx = wx + distance end

    -- Oblicz kierunek
    local worldX, worldY = cam:worldCoords(mx, my)
    local dx, dy = worldX - wx, worldY - wy
    local len = math.sqrt(dx*dx + dy*dy)
    if len > 0 then dx = dx / len; dy = dy / len end

    local isShotgun = (weaponItem.data.name == "Shotgun")

    if isShotgun then
        local pellets = 4
        local spreadAngle = math.pi / 18
        local currentAngle = math.atan2(dy, dx)
        for i = 1, pellets do
            local offset = ((i - 1) / (pellets - 1) - 0.5) * spreadAngle
            local angle = currentAngle + offset
            bullets:spawn(wx, wy, math.cos(angle), math.sin(angle), player.damage, true)
        end
        player.shotgunAmmo = (player.shotgunAmmo or 0) - 4
    else
        bullets:spawn(wx, wy, dx, dy, player.damage, false)
        player.ammo = (player.ammo or 0) - 1
    end
end

return Combat