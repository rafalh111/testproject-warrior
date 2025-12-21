local Stats = {}

function Stats:init(player)
    -- Bazowe wartości
    player.baseDmg = 10
    player.baseMaxHp = 100
    player.baseMaxStamina = 128
    player.baseMaxMana = 20
    player.baseSpeed = 350
    
    -- Inicjalizacja punktów levelingu
    player.baseMaxHpPoints = player.baseMaxHpPoints or 0
    player.baseDamagePoints = player.baseDamagePoints or 0
    player.baseMaxStaminaPoints = player.baseMaxStaminaPoints or 0
    player.baseMaxManaPoints = player.baseMaxManaPoints or 0
    player.baseSpeedPoints = player.baseSpeedPoints or 0

    -- Aktualne wartości
    player.str = player.baseDmg
    player.damage = player.baseDmg
    player.maxHp = player.baseMaxHp
    player.hp = player.maxHp
    player.maxStamina = player.baseMaxStamina
    player.stamina = player.maxStamina
    player.maxMana = player.baseMaxMana
    player.mana = player.maxMana
    player.speed = player.baseSpeed
    
    -- Regeneracja
    player.staminaRegen = 20
    player.staminaDrain = 30
    player.hpRegen = 2  -- Regeneracja 2 HP na sekundę
    player.manaRegen = 10
end

function Stats:calculate(player)
    -- Reset do bazowych
    player.str = player.baseDmg
    player.maxHp = player.baseMaxHp
    player.maxStamina = player.baseMaxStamina
    player.maxMana = player.baseMaxMana
    player.speed = player.baseSpeed

    -- Bonusy z inventory
    local inventoryBonuses = {}
    if _G.inventory and _G.inventory.getBonuses then
        inventoryBonuses = _G.inventory:getBonuses() or {} 
    end
    
    -- Bonusy z levelingu (0.01 = 1%)
    local totalHpBonus = (player.baseMaxHpPoints or 0)/100 + (inventoryBonuses.hp or 0)
    local totalStrBonus = (player.baseDamagePoints or 0)/100 + (inventoryBonuses.str or 0)
    local totalStaminaBonus = (player.baseMaxStaminaPoints or 0)/100 + (inventoryBonuses.stamina or 0)
    local totalManaBonus = (player.baseMaxManaPoints or 0)/100 + (inventoryBonuses.mana or 0)
    local totalSpeedBonus = (player.baseSpeedPoints or 0)/100 + (inventoryBonuses.speed or 0)
    
    -- Aplikacja bonusów
    player.str = player.baseDmg * (1 + totalStrBonus)
    player.maxHp = player.baseMaxHp * (1 + totalHpBonus)
    player.maxStamina = player.baseMaxStamina * (1 + totalStaminaBonus)
    player.maxMana = player.baseMaxMana * (1 + totalManaBonus)
    player.speed = player.baseSpeed * (1 + totalSpeedBonus)

    -- Capowanie wartości
    player.damage = player.str
    
    -- UWAGA: Ta linia powoduje, że HP nie będzie większe niż MaxHP, ale nie wyleczy natychmiast.
    -- Oznacza to, że jeśli MaxHP wzrosło, to HP musi się zregenerować do nowej wartości.
    player.hp = math.min(player.hp, player.maxHp) 
    
    player.stamina = math.min(player.stamina, player.maxStamina)
    player.mana = math.min(player.mana, player.maxMana)
end

function Stats:updateRegen(player, dt)
    -- REGENERACJA HP
    player.hp = math.min(player.maxHp, player.hp + player.hpRegen * dt)
    
    -- REGENERACJA MANY
    player.mana = math.min(player.maxMana, player.mana + player.manaRegen * dt)
    
end

return Stats