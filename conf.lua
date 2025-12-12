-- MOBILE:

function love.conf(t)
	-- Tytuł i ikona okna
	t.window.title = "TestProject"
	t.window.icon = "sprites/icon.png"

	
	t.window.resizable = false
	t.window.fullscreen = true
	
	t.window.fullscreentype = "desktop" 
	-- Flaga mobilna
	t.mobile = true

	-- Inne opcje okna
	t.window.minwidth = 640 	
	t.window.minheight = 480 	
	t.window.vsync = 1
	t.window.msaa = 0

	-- Moduły
	t.modules.joystick = true
	t.modules.audio = true
	t.modules.keyboard = true
	t.modules.event = true
	t.modules.image = true
	t.modules.graphics = true
	t.modules.timer = true
	t.modules.mouse = true
	t.modules.sound = true
	t.modules.physics = true
	
	-- WŁĄCZENIE DOTYKU
	t.modules.touch = true

	
end