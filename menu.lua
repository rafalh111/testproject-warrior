local utf8 = require("utf8")
local menu = {}

-- CZCIONKI (OK)
local largeFont = love.graphics.newFont(24) 
local smallFont = love.graphics.newFont(12) 
local inputFont = love.graphics.newFont(20) 

-- STAN MENU (OK)
menu.buttons = {}
menu.selectedButton = 1

-- Flagi do imienia
menu.gameStarted = false 
menu.playerNameInput = ""
local PLAYER_NAME_MAX_LENGTH = 16

-- Panel ustawień (Zostawiamy tylko stałe rozmiary)
menu.settingsOpen = false
menu.volume = 1 
menu.fpsLimit = 60 
-- Zmienione na lokalne stałe, aby użyć ich do centrowania:
local SETTINGS_WIDTH = 400
local SETTINGS_HEIGHT = 300

-- ZMIANA 1: Nowe zmienne do obsługi kliknięcia/dotyku mobilnego (cooldown)
menu.isMouseDown = false
menu.lastPressTime = 0
local PRESS_THRESHOLD = 0.3 -- Maksymalny czas trwania, aby uznać to za kliknięcie/tapnięcie

-- (Reszta ustawień, keyBindings itp., bez zmian)
menu.keyBindings = {
    Up = "w", Left = "a", Down = "s", Right = "d",
    Inventory = "e", Sprint = "lshift", Jump = "space", Reload = "r",
}
menu.keySettingOpen = false
menu.editingKey = nil 
menu.settingsSelected = 1 
menu.settingsMax = 3
menu.keyBindingsSelected = 1
local keyNamesSorted = {} 

local function GetSortedKeyNames()
    return {
        "Up", "Left", "Down", "Right", "Inventory", 
        "Sprint", "Jump", "Reload",
    }
end

-- NOWA FUNKCJA: Aktualizacja listy przycisków
function menu:updateButtons(Game)
    menu.buttons = {}
    
    local hasName = Game and Game.player and Game.player.name and Game.player.name ~= "NO NAME"
    
    if menu.gameStarted and hasName then
        table.insert(menu.buttons, {text = "Continue", action = "continue"})
        table.insert(menu.buttons, {text = "New Game", action = "start"})
    else
        table.insert(menu.buttons, {text = "Start", action = "start"})
    end
    
    table.insert(menu.buttons, {text = "Options", action = "options"})
    table.insert(menu.buttons, {text = "Quit", action = "quit"})

    menu.selectedButton = math.min(menu.selectedButton, #menu.buttons)
end

-- Start menu (OK)
function menu:init(Game)
    menu:updateButtons(Game) 
    menu.buttonWidth = 200
    menu.buttonHeight = 50
    menu.buttonSpacing = 20
end

-- === POPRAWIONA FUNKCJA: WZNAWIANIE GRY I PRZELICZANIE HUD ===
function menu:resumeGame(Game)
    Game.state = "playing"
    love.keyboard.setTextInput(false) 

    -- ** POPRAWKA CZCIONKI: GWARANCJA POPRAWNEGO ROZMIARU DLA HUD **
    -- Ustawienie smallFont, aby nadpisać inputFont, który został ustawiony w trybie nick_input.
    love.graphics.setFont(smallFont) 
    -- ***************************************************************
    
    -- Krok 1: Wymuszenie odświeżenia KONTROLEK DOTYKOWYCH (NAPRAWIA SKALOWANIE HUD/AMMO)
    if Game.controls and Game.controls.refreshControls then
        Game.controls:refreshControls()
    end
    
    -- Wymuszamy ręczne przeliczenie pozycji HUD po powrocie do gry
    if type(Game.bars) == 'table' and Game.bars.recalculatePosition then
        Game.bars:recalculatePosition()
    end
    
    if type(Game.minimap) == 'table' and Game.minimap.recalculatePosition then
        -- Używamy Game.map przekazanego z main.lua
        Game.minimap:recalculatePosition(Game.map) 
    end
end
--------------------------------------------------------

-- Rysowanie menu
function menu.draw(Game) 
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    if Game.state == "menu" then
        menu:updateButtons(Game) 
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(largeFont) 
    love.graphics.printf("TESTPROJECT", 0, 100, screenWidth, "center")

    -- === RYSOWANIE POLA INPUTU ZALEŻNE OD Game.state ===
    if Game.state == "nick_input" then 
        love.graphics.setFont(inputFont) 
        local prompt = "Enter your name: " .. menu.playerNameInput .. (love.timer.getTime() % 1 < 0.5 and "|" or "")
        
        local inputX = screenWidth / 2 - 200
        local inputY = screenHeight / 2 - 30
        local inputW = 400
        local inputH = 60
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", inputX, inputY, inputW, inputH, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", inputX, inputY, inputW, inputH, 10)

        love.graphics.printf(prompt, inputX + 10, inputY + 15, inputW - 20, "left")
        return 
    end
    --------------------------------------------------------------------
    
    -- === NOWE DYNAMICZNE WYSRODKOWANIE DLA USTAWIEN ===
    local settingsX = screenWidth / 2 - SETTINGS_WIDTH / 2
    local settingsY = screenHeight / 2 - SETTINGS_HEIGHT / 2

    -- Panel ustawień (OK)
    if menu.settingsOpen then
        -- POPRAWKA FONTU: Ustaw smallFont przed rysowaniem ustawień (jeśli weszliśmy bezpośrednio z menu głównego)
        love.graphics.setFont(smallFont) 
        
        love.graphics.setColor(0,0,0,0.8)
        -- Używamy dynamicznych X i Y
        love.graphics.rectangle("fill", settingsX, settingsY, SETTINGS_WIDTH, SETTINGS_HEIGHT, 10, 10)
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle("line", settingsX, settingsY, SETTINGS_WIDTH, SETTINGS_HEIGHT, 10, 10)
        love.graphics.setFont(smallFont)
        love.graphics.printf("Settings", settingsX, settingsY + 10, SETTINGS_WIDTH, "center")

        if menu.keySettingOpen then
            love.graphics.printf("Key Bindings: Esc - Back, Up/Down/WASD - Navigate, Enter/Space - Edit", settingsX + 20, settingsY + 30, SETTINGS_WIDTH-40, "left")
            local keyY = settingsY + 70
            keyNamesSorted = GetSortedKeyNames()

            for i, name in ipairs(keyNamesSorted) do
                local key = menu.keyBindings[name]
                local x = settingsX + 20
                local w = SETTINGS_WIDTH - 40
                local h = 20
                -- POPRAWKA: Dynamiczna pozycja dla tekstu klucza (przesunięcie na prawo w panelu)
                local keyTextX = settingsX + SETTINGS_WIDTH * 0.7 - 30 -- Przesunięcie na ok. 70% szerokości panelu
                local keyTextW = 60

                if i == menu.keyBindingsSelected and not menu.editingKey then
                    love.graphics.setColor(0.1, 0.4, 0.7, 1) 
                    love.graphics.rectangle("fill", keyTextX - 5, keyY - 5, keyTextW + 10, h + 10)
                end

                if menu.editingKey == name then
                    love.graphics.setColor(0.9, 0.5, 0.1, 1)
                    love.graphics.printf("Press a new key for: "..name.."...", x, keyY, w, "left")
                    love.graphics.setColor(0.1, 0.9, 0.1, 1)
                    love.graphics.rectangle("fill", keyTextX, keyY, keyTextW, h)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.printf(string.upper(key), keyTextX, keyY + 5, keyTextW, "center")
                else
                    love.graphics.setColor(1, 1, 1)
                    -- POPRAWKA: Użycie mniejszej szerokości dla tekstu nazwy klucza, aby nie nachodził na wartość
                    love.graphics.printf(name, x, keyY, SETTINGS_WIDTH*0.4, "left") 

                    love.graphics.setColor(0.2, 0.2, 0.2, 1)
                    love.graphics.rectangle("fill", keyTextX, keyY, keyTextW, h)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.rectangle("line", keyTextX, keyY, keyTextW, h)
                    love.graphics.printf(string.upper(key), keyTextX, keyY + 5, keyTextW, "center")
                end
                keyY = keyY + h + 5
            end
            return
        end

        -- STANDARDOWE USTAWIENIA (OK) - Używają dynamicznych X i Y (settingsX, settingsY)
        local volX, volY, volW, volH = settingsX+20, settingsY+70, SETTINGS_WIDTH-40, 15
        if menu.settingsSelected == 1 then
            love.graphics.setColor(0.9, 0.5, 0.1, 1)
            love.graphics.rectangle("line", volX - 5, settingsY+50 - 5, volW + 10, volY + volH - (settingsY+50) + 25)
            love.graphics.setColor(1,1,1)
        end
        love.graphics.printf("Volume: "..math.floor(menu.volume*100).."%", settingsX+20, settingsY+50, SETTINGS_WIDTH-40, "left")
        love.graphics.setColor(0.3,0.3,0.3)
        love.graphics.rectangle("fill", volX, volY, volW, volH)
        love.graphics.setColor(0.1,0.8,0.1)
        love.graphics.rectangle("fill", volX, volY, volW*menu.volume, volH)
        
        local fpsX, fpsY, fpsW, fpsH = settingsX+20, settingsY+130, SETTINGS_WIDTH-40, 15
        if menu.settingsSelected == 2 then
            love.graphics.setColor(0.9, 0.5, 0.1, 1)
            love.graphics.rectangle("line", fpsX - 5, settingsY+110 - 5, fpsW + 10, fpsY + fpsH - (settingsY+110) + 25)
            love.graphics.setColor(1,1,1)
        end
        local fpsText = menu.fpsLimit == "unlimited" and "Unlimited" or tostring(menu.fpsLimit)
        love.graphics.printf("FPS Limit: "..fpsText, settingsX+20, settingsY+110, SETTINGS_WIDTH-40, "left")
        love.graphics.setColor(0.3,0.3,0.3)
        love.graphics.rectangle("fill", fpsX, fpsY, fpsW, fpsH)
        local fpsBar = menu.fpsLimit == "unlimited" and fpsW or fpsW*(menu.fpsLimit/240)
        love.graphics.setColor(0.1,0.1,0.8)
        love.graphics.rectangle("fill", fpsX, fpsY, fpsBar, fpsH)

        local keySettingsX, keySettingsY, keySettingsW, keySettingsH = settingsX+20, settingsY+170, SETTINGS_WIDTH-40, 20
        if menu.settingsSelected == 3 then
            love.graphics.setColor(0.9, 0.5, 0.1, 1)
            love.graphics.rectangle("line", keySettingsX-5, keySettingsY-5, keySettingsW+10, keySettingsH+10)
            love.graphics.setColor(1,1,1)
        end
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.rectangle("fill", keySettingsX, keySettingsY, keySettingsW, keySettingsH)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", keySettingsX, keySettingsY, keySettingsW, keySettingsH)
        love.graphics.printf("Key Bindings", keySettingsX, keySettingsY+5, keySettingsW, "center")

        love.graphics.setColor(1,1,1)
        love.graphics.printf("Arrow Keys / WASD: Navigate, Left/Right: Adjust, Enter: Select, Esc: Back", settingsX+20, settingsY+210, SETTINGS_WIDTH-40, "center")
        return
    end

    -- Rysowanie przycisków (OK)
    -- Ustaw smallFont przed rysowaniem przycisków, jeśli jesteśmy w menu głównym
    love.graphics.setFont(smallFont)
    local startY = screenHeight / 2 - (#menu.buttons * (menu.buttonHeight + menu.buttonSpacing)) / 2
    for i, button in ipairs(menu.buttons) do
        local x = screenWidth / 2 - menu.buttonWidth / 2
        local y = startY + (i - 1) * (menu.buttonHeight + menu.buttonSpacing)

        -- ZMIANA 2: Dodajemy wizualne wsparcie dla naciśniętego przycisku
        local isPressed = (i == menu.selectedButton)
        if menu.isMouseDown and i == menu.selectedButton then
            isPressed = true
        end

        if isPressed then
            love.graphics.setColor(0.3, 0.6, 0.9)
        else
            love.graphics.setColor(0.2, 0.2, 0.2)
        end

        love.graphics.rectangle("fill", x, y, menu.buttonWidth, menu.buttonHeight, 10, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, menu.buttonWidth, menu.buttonHeight, 10, 10)
        love.graphics.printf(button.text, x, y + 15, menu.buttonWidth, "center")
    end
end

-- Obsługa klawiatury
function menu:keypressed(key, Game) 
    local mappedKey = MapKey and MapKey(key) or key
    
    -- Obliczamy dynamiczne X i Y (tylko do logiki dotyku/myszy, ale zostawiamy)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local settingsX = screenWidth / 2 - SETTINGS_WIDTH / 2
    local settingsY = screenHeight / 2 - SETTINGS_HEIGHT / 2


    -- Blokowanie klawiatury dla edycji klawiszy / Ustawień (OK)
    if menu.settingsOpen then
        -- ... (Logika ustawień keypressed bez zmian)
        if menu.keySettingOpen then
            if menu.editingKey then
                if key ~= "escape" then
                    local isKeyTaken = false
                    for k, val in pairs(menu.keyBindings) do
                        if val == key then isKeyTaken = true; break end
                    end
                    if not isKeyTaken then
                        menu.keyBindings[menu.editingKey] = key
                        print("New key for "..menu.editingKey.." set to: "..key)
                    else
                        print("Key "..key.." is already used!")
                    end
                    menu.editingKey = nil
                else
                    menu.editingKey = nil
                end
            else
                local maxBindings = #GetSortedKeyNames()
                if mappedKey == "up" or key == "up" or mappedKey == "w" or key == "w" then
                    menu.keyBindingsSelected = math.max(1, menu.keyBindingsSelected - 1)
                elseif mappedKey == "down" or key == "down" or mappedKey == "s" or key == "s" then
                    menu.keyBindingsSelected = math.min(maxBindings, menu.keyBindingsSelected + 1)
                elseif key == "return" or key == "space" or key == "kpenter" then
                    local keyNames = GetSortedKeyNames()
                    menu.editingKey = keyNames[menu.keyBindingsSelected]
                    print("Editing key: "..menu.editingKey)
                elseif key == "escape" then
                    menu.keySettingOpen = false
                    menu.settingsSelected = 3 -- Powrót do Key Bindings w głównym panelu
                    menu.keyBindingsSelected = 1
                end
            end
            return
        end

        -- Standardowe ustawienia
        if mappedKey == "up" or key == "up" or mappedKey == "w" or key == "w" then
            menu.settingsSelected = math.max(1, menu.settingsSelected - 1)
        elseif mappedKey == "down" or key == "down" or mappedKey == "s" or key == "s" then
            menu.settingsSelected = math.min(menu.settingsMax, menu.settingsSelected + 1)
        elseif key == "escape" then
            menu.settingsOpen = false
        end

        if menu.settingsSelected == 1 then -- Głośność
            if mappedKey == "left" or key == "left" or mappedKey == "a" or key == "a" then
                menu.volume = math.max(0, menu.volume - 0.05)
                love.audio.setVolume(menu.volume)
            elseif mappedKey == "right" or key == "right" or mappedKey == "d" or key == "d" then
                menu.volume = math.min(1, menu.volume + 0.05)
                love.audio.setVolume(menu.volume)
            end
        elseif menu.settingsSelected == 2 then -- Limit FPS
            if mappedKey == "left" or key == "left" or mappedKey == "a" or key == "a" then
                if menu.fpsLimit == "unlimited" then
                    menu.fpsLimit = 240
                else
                    menu.fpsLimit = math.max(15, menu.fpsLimit - 5)
                end
            elseif mappedKey == "right" or key == "right" or mappedKey == "d" or key == "d" then
                if menu.fpsLimit == 240 then
                    menu.fpsLimit = "unlimited"
                elseif menu.fpsLimit ~= "unlimited" then
                    menu.fpsLimit = math.min(240, menu.fpsLimit + 5)
                end
            end
        elseif menu.settingsSelected == 3 then -- Przycisk Key Bindings
            if key == "return" or key == "space" or key == "kpenter" then
                menu.keySettingOpen = true
                menu.keyBindingsSelected = 1
            end
        end
        return
    end

    -- === Obsługa wprowadzania imienia ===
    if Game.state == "nick_input" then
        if key == "backspace" then
            local byteoffset = utf8.offset(menu.playerNameInput, -1)
            if byteoffset then
                menu.playerNameInput = string.sub(menu.playerNameInput, 1, byteoffset - 1)
            end
        elseif key == "return" or key == "kpenter" then
            local enteredName = menu.playerNameInput
            if enteredName == "" then enteredName = "Player" end 
            
            if Game.player then
                Game.player.name = enteredName
            end
            
            menu.gameStarted = true
            menu.playerNameInput = "" 
            menu:updateButtons(Game) 
            
            menu:resumeGame(Game) -- ZMIANA: Używamy nowej funkcji (gdzie czcionka jest resetowana)
            return
        end
        return
    end

    -- Nawigacja po menu głównym
    if mappedKey == "up" or key == "up" then
        menu.selectedButton = menu.selectedButton - 1
        if menu.selectedButton < 1 then menu.selectedButton = #menu.buttons end
    elseif mappedKey == "down" or key == "down" then
        menu.selectedButton = menu.selectedButton + 1
        if menu.selectedButton > #menu.buttons then menu.selectedButton = 1 end
    elseif key == "return" or key == "space" or key == "kpenter" then 
        local btn = menu.buttons[menu.selectedButton]
        
        if btn.action == "start" then
            Game.state = "nick_input" 
            love.keyboard.setTextInput(true) 
            return
        elseif btn.action == "continue" then
            menu:resumeGame(Game) -- ZMIANA: Używamy nowej funkcji
            return
        elseif btn.action == "options" then
            menu.settingsOpen = true
            menu.settingsSelected = 1
            return
        else 
            return menu:selectButton()
        end
    end
end

-- Obsługa myszy / dotyku
function menu:mousepressed(x, y, button, Game) 
    if button == 1 then
        
        menu.isMouseDown = true -- ZMIANA 3: Rejestrujemy naciśnięcie
        menu.lastPressTime = love.timer.getTime() -- ZMIANA 3: Rejestrujemy czas
        
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        -- Obliczamy dynamiczne X i Y
        local settingsX = screenWidth / 2 - SETTINGS_WIDTH / 2
        local settingsY = screenHeight / 2 - SETTINGS_HEIGHT / 2
        
        -- === PRIORYTET 1: Logika wprowadzania nazwy ZALEŻNA OD STANU GRY ===
        if Game.state == "nick_input" then
            -- Tylko oznaczamy, że mysz jest naciśnięta, akcja (opuszczenie) nastąpi w mousereleased
            return
        end

        -- === PRIORYTET 2: Logika ustawień (OK) ===
        if menu.settingsOpen then
            -- Mimo że przenosimy akcję przycisków menu na released, suwaki i wybór klawiszy MUSZĄ być w pressed
            
            if menu.keySettingOpen then
                local keyY = settingsY + 70
                local w = SETTINGS_WIDTH - 40
                local h = 20
                local keyX = settingsX + SETTINGS_WIDTH * 0.7 - 30 
                keyNamesSorted = GetSortedKeyNames()

                for i, name in ipairs(keyNamesSorted) do
                    -- Sprawdzenie kliknięcia na przycisk z klawiszem
                    if x >= keyX and x <= keyX + 60 and y >= keyY and y <= keyY + h then
                        menu.keyBindingsSelected = i
                        menu.editingKey = name
                        return
                    end
                    keyY = keyY + h + 5
                end
                return
            end

            local keySettingsX = settingsX+20
            local keySettingsY = settingsY+170
            local keySettingsW = SETTINGS_WIDTH-40
            -- Kliknięcie na przycisk Key Bindings
            if x >= keySettingsX and x <= keySettingsX + keySettingsW and y >= keySettingsY and y <= keySettingsY + 20 then
                menu.settingsSelected = 3
                -- NIE WYWOŁUJEMY ZMIANY STANU (menu.keySettingOpen = true) TUTAJ, CZEKAMY NA MOUSERELEASED
                return
            end

            local volX = settingsX + 20
            local volY = settingsY + 70
            local volW = SETTINGS_WIDTH-40
            local volH = 15
            -- Kliknięcie na suwak głośności
            if x >= volX and x <= volX + volW and y >= volY and y <= volY + volH then
                menu.volume = math.max(0, math.min(1, (x - volX)/volW))
                love.audio.setVolume(menu.volume)
                menu.settingsSelected = 1
                return
            end

            local fpsX = settingsX + 20
            local fpsY = settingsY + 130
            local fpsW = SETTINGS_WIDTH-40
            local fpsH = 15
            -- Kliknięcie na suwak FPS
            if x >= fpsX and x <= fpsX + fpsW and y >= fpsY and y <= fpsY + fpsH then
                local pos = (x - fpsX)/fpsW
                if pos > 0.98 then
                    menu.fpsLimit = "unlimited"
                else
                    menu.fpsLimit = math.floor(pos*240/5)*5
                end
                menu.settingsSelected = 2
                return
            end
            
            -- Jeśli kliknięto poza panelem ustawień, zamykamy go
            local settingsBoundaryX = settingsX
            local settingsBoundaryY = settingsY
            local settingsBoundaryW = SETTINGS_WIDTH
            local settingsBoundaryH = SETTINGS_HEIGHT
            if not (x >= settingsBoundaryX and x <= settingsBoundaryX + settingsBoundaryW and y >= settingsBoundaryY and y <= settingsBoundaryY + settingsBoundaryH) then
                -- Zamykamy ustawienia NATYCHMIAST
                menu.settingsOpen = false
                return 
            end
            
            return
        end

        -- === PRIORYTET 3: Logika menu głównego ===
        if Game.state == "menu" then 
            local startY = screenHeight / 2 - (#menu.buttons * (menu.buttonHeight + menu.buttonSpacing)) / 2

            for i, btn in ipairs(menu.buttons) do
                local bx = screenWidth / 2 - menu.buttonWidth / 2
                local by = startY + (i - 1) * (menu.buttonHeight + menu.buttonSpacing)

                if x >= bx and x <= bx + menu.buttonWidth and y >= by and y <= by + menu.buttonHeight then
                    -- Tylko zaznaczamy przycisk. Akcja nastąpi w mousereleased.
                    menu.selectedButton = i
                    return
                end
            end
        end
    end
end


-- ZMIANA 4: DODANIE FUNKCJI MOUSERELEASED
function menu:mousereleased(x, y, button, Game)
    menu.isMouseDown = false
    
    if button == 1 then
        local pressDuration = love.timer.getTime() - menu.lastPressTime
        local isTap = pressDuration < PRESS_THRESHOLD -- Sprawdzenie, czy to było szybkie tapnięcie
        
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local settingsX = screenWidth / 2 - SETTINGS_WIDTH / 2
        local settingsY = screenHeight / 2 - SETTINGS_HEIGHT / 2

        -- === PRIORYTET 1: Logika wprowadzania nazwy (wyjście) ===
        if Game.state == "nick_input" and isTap then
            local inputX = screenWidth / 2 - 200
            local inputY = screenHeight / 2 - 30
            local inputW = 400
            local inputH = 60
            
            -- Jeśli kliknięto poza polem input, wychodzimy z trybu wprowadzania nicka
            if not (x >= inputX and x <= inputX + inputW and y >= inputY and y <= inputY + inputH) then
                love.keyboard.setTextInput(false)
                menu:updateButtons(Game) 
                Game.state = "menu" 
                return
            end
        end


        -- === PRIORYTET 2: Logika ustawień (Przycisk Key Bindings) ===
        if menu.settingsOpen and isTap then
            local keySettingsX = settingsX+20
            local keySettingsY = settingsY+170
            local keySettingsW = SETTINGS_WIDTH-40
            
            -- Kliknięcie na przycisk Key Bindings
            if x >= keySettingsX and x <= keySettingsX + keySettingsW and y >= keySettingsY and y <= keySettingsY + 20 then
                menu.settingsSelected = 3
                menu.keySettingOpen = true -- Zmieniamy stan dopiero po released
                menu.keyBindingsSelected = 1
                return
            end
        end
        
        -- === PRIORYTET 3: Logika menu głównego ===
        if Game.state == "menu" and isTap then 
            local startY = screenHeight / 2 - (#menu.buttons * (menu.buttonHeight + menu.buttonSpacing)) / 2

            for i, btn in ipairs(menu.buttons) do
                local bx = screenWidth / 2 - menu.buttonWidth / 2
                local by = startY + (i - 1) * (menu.buttonHeight + menu.buttonSpacing)

                -- Sprawdź, czy puszczono w obrębie zaznaczonego przycisku (menu.selectedButton)
                if x >= bx and x <= bx + menu.buttonWidth and y >= by and y <= by + menu.buttonHeight and i == menu.selectedButton then
                    
                    if btn.action == "start" then
                        Game.state = "nick_input" 
                        love.keyboard.setTextInput(true) 
                        return
                    elseif btn.action == "continue" then
                        menu:resumeGame(Game) 
                        return
                    elseif btn.action == "options" then
                        menu.settingsOpen = true
                        menu.settingsSelected = 1
                        return
                    else
                        return menu:selectButton()
                    end
                end
            end
        end
    end
end


-- Akcja po wybraniu przycisku (OK)
function menu:selectButton()
    local action = menu.buttons[menu.selectedButton].action
    return action
end

-- Obsługa wpisywania liter
function menu:textinput(t, Game) 
    if Game.state == "nick_input" and utf8.len(menu.playerNameInput) < PLAYER_NAME_MAX_LENGTH then
        menu.playerNameInput = menu.playerNameInput .. t
    end
end

-- ZMIANA 5: Eksportujemy funkcję mousereleased
menu.mousereleased = menu.mousereleased

return menu