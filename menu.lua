local utf8 = require("utf8")
local menu = {}

-- STAN MENU
menu.buttons = {}
menu.selectedButton = 1

-- Flagi do imienia
menu.nameEntered = false
menu.nameInputActive = false
menu.playerNameInput = ""

-- Panel ustawień
menu.settingsOpen = false
menu.volume = 1 -- 0.0 - 1.0
menu.fpsLimit = 60 -- max fps
menu.settingsX = 315
menu.settingsY = 150
menu.settingsWidth = 400
menu.settingsHeight = 300
local smallFont = love.graphics.newFont(12)

-- Ustawienie Klawiszy
menu.keyBindings = {
Up = "w",
Left = "a",
Down = "s",
Right = "d",
Inventory = "e",
Sprint = "lshift",
Jump = "space",
Reload = "r",
}
menu.keySettingOpen = false
menu.editingKey = nil 

-- NAWIGACJA W USTAWIACH
menu.settingsSelected = 1 
menu.settingsMax = 3

-- NAWIGACJA W KEY BINDINGS
menu.keyBindingsSelected = 1
local keyNamesSorted = {} 

-- FUNKCJA ZMODYFIKOWANA: Zwraca stałą listę akcji w preferowanej kolejności
local function GetSortedKeyNames()
    return {
        "Up",
        "Left",
        "Down",
        "Right",
        "Inventory",
        "Sprint",
        "Jump",
        "Reload",
    }
end

-- Start menu
function menu:init()
    menu.buttons = {
        {text = "Start", action = "start"},
        {text = "Options", action = "options"},
        {text = "Quit", action = "quit"}
    }
    menu.buttonWidth = 200
    menu.buttonHeight = 50
    menu.buttonSpacing = 20
end

-- Rysowanie menu
function menu.draw()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("TESTPROJECT", 0, 100, screenWidth, "center")

    -- Panel ustawień
    if menu.settingsOpen then
        love.graphics.setColor(0,0,0,0.8)
        love.graphics.rectangle("fill", menu.settingsX, menu.settingsY, menu.settingsWidth, menu.settingsHeight, 10, 10)
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle("line", menu.settingsX, menu.settingsY, menu.settingsWidth, menu.settingsHeight, 10, 10)
        love.graphics.setFont(smallFont)
        love.graphics.printf("Settings", menu.settingsX, menu.settingsY + 10, menu.settingsWidth, "center")

        if menu.keySettingOpen then
            love.graphics.printf("Key Bindings: Esc - Back, Up/Down/WASD - Navigate, Enter/Space - Edit", menu.settingsX + 20, menu.settingsY + 30, menu.settingsWidth-40, "left")

            local keyY = menu.settingsY + 70
            keyNamesSorted = GetSortedKeyNames()

            for i, name in ipairs(keyNamesSorted) do
                local key = menu.keyBindings[name]
                local x = menu.settingsX + 20
                local w = menu.settingsWidth - 40
                local h = 20
                local keyTextX = x + w/2 + 20
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
                    love.graphics.printf(name, x, keyY, w/2, "left")

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

        -- === STANDARDOWE USTAWIENIA ===
        -- 1. Głośność
        local volX, volY, volW, volH = menu.settingsX+20, menu.settingsY+70, menu.settingsWidth-40, 15
        if menu.settingsSelected == 1 then
            love.graphics.setColor(0.9, 0.5, 0.1, 1)
            love.graphics.rectangle("line", volX - 5, menu.settingsY+50 - 5, volW + 10, volY + volH - (menu.settingsY+50) + 25)
            love.graphics.setColor(1,1,1)
        end
        love.graphics.printf("Volume: "..math.floor(menu.volume*100).."%", menu.settingsX+20, menu.settingsY+50, menu.settingsWidth-40, "left")
        love.graphics.setColor(0.3,0.3,0.3)
        love.graphics.rectangle("fill", volX, volY, volW, volH)
        love.graphics.setColor(0.1,0.8,0.1)
        love.graphics.rectangle("fill", volX, volY, volW*menu.volume, volH)
        
        -- 2. FPS
        local fpsX, fpsY, fpsW, fpsH = menu.settingsX+20, menu.settingsY+130, menu.settingsWidth-40, 15
        if menu.settingsSelected == 2 then
            love.graphics.setColor(0.9, 0.5, 0.1, 1)
            love.graphics.rectangle("line", fpsX - 5, menu.settingsY+110 - 5, fpsW + 10, fpsY + fpsH - (menu.settingsY+110) + 25)
            love.graphics.setColor(1,1,1)
        end
        local fpsText = menu.fpsLimit == "unlimited" and "Unlimited" or tostring(menu.fpsLimit)
        love.graphics.printf("FPS Limit: "..fpsText, menu.settingsX+20, menu.settingsY+110, menu.settingsWidth-40, "left")
        love.graphics.setColor(0.3,0.3,0.3)
        love.graphics.rectangle("fill", fpsX, fpsY, fpsW, fpsH)
        local fpsBar = menu.fpsLimit == "unlimited" and fpsW or fpsW*(menu.fpsLimit/240)
        love.graphics.setColor(0.1,0.1,0.8)
        love.graphics.rectangle("fill", fpsX, fpsY, fpsBar, fpsH)

        -- 3. Przycisk Ustawienia klawiszy
        local keySettingsX, keySettingsY, keySettingsW, keySettingsH = menu.settingsX+20, menu.settingsY+170, menu.settingsWidth-40, 20
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
        love.graphics.printf("Arrow Keys / WASD: Navigate, Left/Right: Adjust, Enter: Select, Esc: Back", menu.settingsX+20, menu.settingsY+210, menu.settingsWidth-40, "center")
        return
    end

    -- Jeśli aktywny input imienia
    if menu.nameInputActive then
        love.graphics.printf("Enter your name: " .. menu.playerNameInput, 0, screenHeight / 2 - 20, screenWidth, "center")
        return
    end

    -- Rysowanie przycisków
    local startY = screenHeight / 2 - (#menu.buttons * (menu.buttonHeight + menu.buttonSpacing)) / 2
    for i, button in ipairs(menu.buttons) do
        local x = screenWidth / 2 - menu.buttonWidth / 2
        local y = startY + (i - 1) * (menu.buttonHeight + menu.buttonSpacing)

        if i == menu.selectedButton then
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
function menu:keypressed(key)
    local mappedKey = MapKey and MapKey(key) or key

    if menu.settingsOpen then
        if menu.keySettingOpen then
            if menu.editingKey then
                if key ~= "escape" then
                    local isKeyTaken = false
                    for k, val in pairs(menu.keyBindings) do
                        if val == key then
                            isKeyTaken = true
                            break
                        end
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
                    menu.keyBindingsSelected = 1
                end
            end
            return
        end

        -- === STANDARDOWE USTAWIENIA: Nawigacja w Options ===
        if mappedKey == "up" or key == "up" or mappedKey == "w" or key == "w" then
            menu.settingsSelected = math.max(1, menu.settingsSelected - 1)
        elseif mappedKey == "down" or key == "down" or mappedKey == "s" or key == "s" then
            menu.settingsSelected = math.min(menu.settingsMax, menu.settingsSelected + 1)
        elseif key == "escape" then
            menu.settingsOpen = false
        end

        -- === STANDARDOWE USTAWIENIA: Zmiana wartości (Left/Right) lub Wybór (Enter/Space) ===
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

    if menu.nameInputActive then
        if key == "backspace" then
            local byteoffset = utf8.offset(menu.playerNameInput, -1)
            if byteoffset then
                menu.playerNameInput = string.sub(menu.playerNameInput, 1, byteoffset - 1)
            end
        elseif key == "return" or key == "kpenter" then
            if menu.playerNameInput ~= "" then
                playerName = menu.playerNameInput 
            else
                playerName = "blank"
            end
            menu.nameInputActive = false
            menu.nameEntered = true
            return "start"
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
        if btn.action == "start" and not menu.nameEntered then
            menu.nameInputActive = true
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

-- Obsługa myszy
function menu:mousepressed(x, y, button)
    if button == 1 then
        if menu.settingsOpen then
            if menu.keySettingOpen then
                local keyY = menu.settingsY + 70
                local w = menu.settingsWidth - 40
                local h = 20
                local keyX = menu.settingsX + 20 + w/2 + 20

                keyNamesSorted = GetSortedKeyNames()

                for i, name in ipairs(keyNamesSorted) do
                    if x >= keyX and x <= keyX + 60 and y >= keyY and y <= keyY + h then
                        menu.keyBindingsSelected = i
                        menu.editingKey = name
                        return
                    end
                    keyY = keyY + h + 5
                end
                return
            end

            -- Klik na przycisk "Key Bindings"
            local keySettingsX = menu.settingsX+20
            local keySettingsY = menu.settingsY+170
            local keySettingsW = menu.settingsWidth-40
            if x >= keySettingsX and x <= keySettingsX + keySettingsW and y >= keySettingsY and y <= keySettingsY + 20 then
                menu.settingsSelected = 3
                menu.keySettingOpen = true
                menu.keyBindingsSelected = 1
                return
            end

            -- Klik na suwak głośności
            local volX = menu.settingsX + 20
            local volY = menu.settingsY + 70
            local volW = menu.settingsWidth-40
            local volH = 15
            if x >= volX and x <= volX + volW and y >= volY and y <= volY + volH then
                menu.volume = math.max(0, math.min(1, (x - volX)/volW))
                love.audio.setVolume(menu.volume)
                menu.settingsSelected = 1
                return
            end

            -- Klik na suwak FPS
            local fpsX = menu.settingsX + 20
            local fpsY = menu.settingsY + 130
            local fpsW = menu.settingsWidth-40
            local fpsH = 15
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
            
            return
        end

        -- Normalne przyciski
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local startY = screenHeight / 2 - (#menu.buttons * (menu.buttonHeight + menu.buttonSpacing)) / 2

        for i, btn in ipairs(menu.buttons) do
            local bx = screenWidth / 2 - menu.buttonWidth / 2
            local by = startY + (i - 1) * (menu.buttonHeight + menu.buttonSpacing)

            if x >= bx and x <= bx + menu.buttonWidth and y >= by and y <= by + menu.buttonHeight then
                menu.selectedButton = i
                if btn.action == "start" and not menu.nameEntered then
                    menu.nameInputActive = true
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

-- Akcja po wybraniu przycisku
function menu:selectButton()
    local action = menu.buttons[menu.selectedButton].action
    return action
end

-- Obsługa wpisywania liter
function menu:textinput(t)
    if menu.nameInputActive then
        menu.playerNameInput = menu.playerNameInput .. t
    end
end

return menu