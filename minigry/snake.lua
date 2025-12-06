-- snake.lua
local snake = {}

function snake:load()
    self.cellSize = 20
    self.gridWidth = math.floor(love.graphics.getWidth() / self.cellSize)
    self.gridHeight = math.floor(love.graphics.getHeight() / self.cellSize)

    self.snake = {{x = 25, y = 20}}
    self.direction = "right"
    self.nextDirection = "right"
    self.snakeLength = 1

    self.food = {x = math.random(0, self.gridWidth - 1), y = math.random(0, self.gridHeight - 1)}

    self.gameOver = false
    self.timer = 0
    self.speed = 0.1

    self.score = 0  -- licznik punktów

    -- ZMIENNE DLA WIZUALIZERA TŁA (PŁYNNA ZMIANA KOLORU REGULOWANA MUZYKĄ)
    self.backgroundColor = 0.0 -- Aktualna jasność (0.0=czarny, 1.0=biały)
    self.backgroundDirection = 1 -- 1: rośnie (czarny -> biały), -1: maleje (biały -> czarny)
    self.baseBackgroundSpeed = 0.01 -- Bazowa prędkość zmiany (np. pełny cykl w 20 sekund)
    self.volumeMultiplier = 2 -- Jak mocno głośność wpływa na prędkość
    
    -- DODANIE MUZYKI
    self.music = love.audio.newSource("hope.mp3", "stream")
    self.music:setLooping(true)
    self.music:play()
end

function snake:update(dt)
    -- Logika Game Over i Muzyki
    if self.gameOver then 
        if self.music and self.music:isPlaying() then
            self.music:pause()
        end
        return 
    end

    if self.music and not self.music:isPlaying() then
        self.music:play()
    end
    
    -- LOGIKA PŁYNNEJ ZMIANY KOLORU TŁA REGULOWANEJ MUZYKĄ
    
    -- 1. Pobieranie głośności (amplitudy)
    local currentVolume = love.audio.getVolume()
    
    -- 2. Ustalanie dynamicznej prędkości
    -- Prędkość = Prędkość bazowa + (Głośność * Mnożnik)
    -- Przy cichej muzyce prędkość będzie bliska basdeBackgroundSpeed.
    -- Przy głośnej muzyce prędkość zostanie zwiększona, przyspieszając cykl.
    local dynamicSpeed = self.baseBackgroundSpeed + (currentVolume * self.volumeMultiplier)
    
    -- 3. Płynna zmiana koloru tła
    self.backgroundColor = self.backgroundColor + self.backgroundDirection * dynamicSpeed * dt
    
    -- 4. Ograniczenie koloru do zakresu [0, 1] i zmiana kierunku
    if self.backgroundColor >= 1.0 then
        self.backgroundColor = 1.0
        self.backgroundDirection = -1 -- Zaczyna iść w stronę czerni
    elseif self.backgroundColor <= 0.0 then
        self.backgroundColor = 0.0
        self.backgroundDirection = 1  -- Zaczyna iść w stronę bieli
    end
    
    -- LOGIKA RUCHU WĘŻA
    self.timer = self.timer + dt
    if self.timer >= self.speed then
        self.timer = self.timer - self.speed

        self.direction = self.nextDirection
        local head = {x = self.snake[1].x, y = self.snake[1].y}

        if self.direction == "right" then head.x = head.x + 1
        elseif self.direction == "left" then head.x = head.x - 1
        elseif self.direction == "up" then head.y = head.y - 1
        elseif self.direction == "down" then head.y = head.y + 1
        end

        -- Kolizja ze ścianą
        if head.x < 0 or head.y < 0 or head.x >= self.gridWidth or head.y >= self.gridHeight then
            self.gameOver = true
            return
        end

        -- Kolizja z samym sobą
        for _, segment in ipairs(self.snake) do
            if segment.x == head.x and segment.y == head.y then
                self.gameOver = true
                return
            end
        end

        table.insert(self.snake, 1, head)
        if #self.snake > self.snakeLength then
            table.remove(self.snake)
        end

        -- Jedzenie
        if head.x == self.food.x and head.y == self.food.y then
            self.snakeLength = self.snakeLength + 1
            self.score = self.score + 1
    
            -- Przyspieszenie
            local speed_decrement = 0.0020 -- Wartość, o jaką zmniejszamy speed (czyli przyspieszamy)
            local min_speed = 0.05        -- Minimalna prędkość, jaką może osiągnąć wąż
            self.speed = math.max(self.speed - speed_decrement, min_speed)
            repeat
                self.food.x = math.random(0, self.gridWidth - 1)
                self.food.y = math.random(0, self.gridHeight - 1)
                local occupied = false
                for _, segment in ipairs(self.snake) do
                    if segment.x == self.food.x and segment.y == self.food.y then
                        occupied = true
                        break
                    end
                end
            until not occupied
        end
    end
end

function snake:draw()
    -- Ustawienie koloru tła na podstawie self.backgroundColor
    local bg = self.backgroundColor
    love.graphics.setBackgroundColor(bg, bg, bg)
    
    -- Wąż (kolory segmentów)
    local rower
    for i, segment in ipairs(self.snake) do
        rower = 1/self.snakeLength * i
        love.graphics.setColor(rower, self.snakeLength/2, math.abs(1 - rower * 2))
        love.graphics.rectangle("fill", segment.x * self.cellSize, segment.y * self.cellSize, self.cellSize, self.cellSize)
    end

    -- Jedzenie
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", self.food.x * self.cellSize, self.food.y * self.cellSize, self.cellSize, self.cellSize)


    -- Punkty (kontrastowy kolor tekstu)
    local text_color = (self.backgroundColor < 0.5) and {1, 1, 1} or {0, 0, 0}
    love.graphics.setColor(text_color[1], text_color[2], text_color[3])
    love.graphics.print("Score: " .. self.score, 10, 10)

    -- Game Over
    if self.gameOver then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Game Over! Press ENTER to restart", 0, love.graphics.getHeight()/2 - 10, love.graphics.getWidth(), "center")
        love.graphics.printf("Your score was: " .. self.score, 0, love.graphics.getHeight()/2 + 20, love.graphics.getWidth(), "center")
    end
end

function snake:keypressed(key)
    key = MapKey(key)
    if (key == "up") and self.direction ~= "down" then
        self.nextDirection = "up"
    elseif (key == "down") and self.direction ~= "up" then
        self.nextDirection = "down"
    elseif (key == "left") and self.direction ~= "right" then
        self.nextDirection = "left"
    elseif (key == "right") and self.direction ~= "left" then
        self.nextDirection = "right"
    elseif key == "return" and self.gameOver then
        -- Zatrzymanie muzyki, aby load() odtworzyło ją od nowa
        if self.music then
            self.music:stop()
        end
        self:load() 
    elseif key == "escape" then
        -- Zatrzymanie muzyki przy wyjściu
        if self.music then
            self.music:stop()
        end
        if self.onExit then
            self.onExit()
        end
    end
end

-- Funkcja callback ustawiana w main.lua
snake.onExit = nil

return snake