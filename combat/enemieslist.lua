local EnemyDefinitions = {}

-- Zmienne globalne do późniejszego dostępu przez ID
EnemyDefinitions.SLIME_ID = "SLIME_01"
EnemyDefinitions.RED_SLIME_ID = "SLIME_02"
EnemyDefinitions.BLUE_SLIME_ID = "SLIME_03" 	
EnemyDefinitions.GREEN_SLIME_ID = "SLIME_04"
EnemyDefinitions.DUMMY_ID = "DUMMY_05"
EnemyDefinitions.BIGDUMMY_ID = "BIGDUMMY_06"
EnemyDefinitions.BOSS_SLIME_ID = "BOSS_SLIME_07"


-- Tabela definicji bazowych statystyk dla każdego typu wroga
EnemyDefinitions.list = {
	[EnemyDefinitions.DUMMY_ID] = {
		name = "Dummy",
		maxHp = 200,
		width = 50, 
		height = 100,
		dmgTextOffsetY = 30,
		isStatic = true,
		renderKey = "DUMMY_RENDER",
		xpMin = 0,
		xpMax = 0
	},
	
	[EnemyDefinitions.BIGDUMMY_ID] = {
		name = "Big Dummy",
		maxHp = 500,
		width = 100,
		height = 150,
		dmgTextOffsetY = 30,
		isStatic = true,
		renderKey = "DUMMY_RENDER",
		xpMin = 0,
		xpMax = 0
	},
	
	-- DEFINICJA BIAŁEGO SLIME'A
	[EnemyDefinitions.SLIME_ID] = {
		name = "White Slime",
		maxHp = 50, 
		width = 40, 
		height = 40,
		dmgTextOffsetY = 10,
		isStatic = false, 
		renderKey = "SLIME_RENDER",
		xpMin = 2,
		xpMax = 4,
		
		renderData = {
			spritePath = "sprites/basicslime.png",
			frameWidth = 64,
			frameHeight = 64,
			maxFrames = 7,
			animationSpeed = 0.15,
			defaultScale = 4.0,
			
			colorCycleActive = false
		}
	},
	
	-- DEFINICJA CZERWONEGO SLIME'A
	[EnemyDefinitions.RED_SLIME_ID] = {
		name = "Red Slime",
		maxHp = 80,
		width = 45, 
		height = 45,
		dmgTextOffsetY = 10,
		isStatic = false, 
		renderKey = "SLIME_RENDER",
		xpMin = 4,
		xpMax = 7,
		
		renderData = {
			spritePath = "sprites/redslime.png",
			frameWidth = 64,
			frameHeight = 64,
			maxFrames = 7,
			animationSpeed = 0.15,
			defaultScale = 4.5,
			
			colorCycleActive = false
		}
	},
	
	-- DEFINICJA NIEBIESKIEGO SLIME'A
	[EnemyDefinitions.BLUE_SLIME_ID] = {
		name = "Blue Slime",
		maxHp = 40,
		width = 35, 
		height = 35,
		dmgTextOffsetY = 10,
		isStatic = false, 
		renderKey = "SLIME_RENDER", 
		xpMin = 1,
		xpMax = 2,
		
		renderData = {
			spritePath = "sprites/waterslime.png",
			frameWidth = 64,
			frameHeight = 64,
			maxFrames = 7,
			animationSpeed = 0.1,
			defaultScale = 3.5,
			
			colorCycleActive = false
		}
	},
	
	-- DEFINICJA ZIELONEGO SLIME'A
	[EnemyDefinitions.GREEN_SLIME_ID] = {
		name = "Green Slime",
		maxHp = 60,
		width = 40, 
		height = 35,
		dmgTextOffsetY = 10,
		isStatic = false, 
		renderKey = "SLIME_RENDER", 
		xpMin = 3,
		xpMax = 5,
		
		renderData = {
			spritePath = "sprites/greenslime.png",
			frameWidth = 64,
			frameHeight = 64,
			maxFrames = 7,
			animationSpeed = 0.1,
			defaultScale = 3.5,
			
			colorCycleActive = false
		}
	},

	-- DEFINICJA BOSSA SLIME'A
	[EnemyDefinitions.BOSS_SLIME_ID] = {
		name = "Boss Slime",
		maxHp = 1000, 
		width = 100, 
		height = 80,
		dmgTextOffsetY = 100,
		isStatic = false, 
		renderKey = "SLIME_RENDER",
		xpMin = 50,
		xpMax = 75,
		
		renderData = {
			spritePath = "sprites/bossslime.png",
			frameWidth = 64,
			frameHeight = 64,
			maxFrames = 7,
			animationSpeed = 0.15,
			defaultScale = 12.0,
			
			-- PARAMETRY CYKLU KOLORÓW (TĘCZA) DLA BOSSA
			colorCycleActive = true,
			colorCycleSpeed = 0.5, 
			colorCycleList = {
				{1.0, 0.0, 0.0}, -- Czerwony
				{1.0, 1.0, 0.0}, -- Żółty
				{0.0, 1.0, 0.0}, -- Zielony
				{0.0, 1.0, 1.0}, -- Cyan
				{0.0, 0.0, 1.0}, -- Niebieski
				{1.0, 0.0, 1.0}  -- Magenta
			}
		}
	}
}

return EnemyDefinitions