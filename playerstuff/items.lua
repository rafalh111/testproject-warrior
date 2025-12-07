local items = {
    Coin = {
        id = 1,
        name = "Coin",
        desc = "Gold Coin",
        imagePath = "sprites/coin.png",
        image = nil,
        bonuses = {},
        type = "misc"
    },
    BUZZGAREN = {
        id = 2,
        name = "BUZZGAREN",
        desc = "CHAOS SPEED SQUARE. +50% movement speed.",
        imagePath = "sprites/test.png",
        image = nil,
        bonuses = { speed = 0.5 },
        type = "artifact"
    },
    StaminaRing = {
        id = 3,
        name = "Stamina Ring",
        desc = "Ring that you picked up in random sewage. +25% stamina",
        imagePath = "sprites/ring.png",
        image = nil,
        bonuses = { stamina = 0.25 },
        type = "artifact"
    },
    AssaultRifle = {
        id = 4,
        name = "AssaultRifle",
        desc = "32 AMMO capacity rifle ready to shoot. +20% dmg",
        imagePath = "sprites/AssaultRifle.png",
        image = nil,
        bonuses = { str = 0.2 },
        type = "weapon"
    },
    Shotgun = {
        id = 9,
        name = "Shotgun",
        desc = "8 AMMO capacity shotgun ready to shoot. +150% dmg",
        imagePath = "sprites/AssaultRifle.png",
        image = nil,
        bonuses = { str = 1.5 },
        type = "weapon"
    },
    helmet = {
        id = 5,
        name = "helmet",
        desc = "Good Iron Helmet. +10% HP",
        imagePath = "sprites/helmet.png",
        image = nil,
        bonuses = { hp = 0.1 },
        type = "helmet"
    },
    chestplate = {
        id = 6,
        name = "chestplate",
        desc = "Good Iron Chestplate. +30% HP",
        imagePath = "sprites/chestplate.png",
        image = nil,
        bonuses = { hp = 0.3 },
        type = "chestplate"
    },
    leggins = {
        id = 7,
        name = "leggins",
        desc = "Good Iron Leggins. +10% HP",
        imagePath = "sprites/leggins.png",
        image = nil,
        bonuses = { hp = 0.1 },
        type = "leggins"
    },
    boots = {
        id = 8,
        name = "boots",
        desc = "Good Iron Boots. +20% HP",
        imagePath = "sprites/boots.png",
        image = nil,
        bonuses = { hp = 0.2 },
        type = "boots"
    },
    Kalejdoskop = {
        id = 10,
        name = "KALEJDOSKOP",
        desc = "Kręci, tak idealnie. Zmienia wizje, możesz zobaczyć ukryte rzeczy na mapie - Bomboclat",
        imagePath = nil,
        image = nil,
        type = "artifact"
    }
}

-- Funkcja inicjalizująca obrazki
function items:loadImages()
    for _, item in pairs(self) do
        -- sprawdzamy czy item to tabela z imagePath
        if type(item) == "table" and item.imagePath then
            item.image = love.graphics.newImage(item.imagePath)
        end
    end
end


return items
