local Movement = {}

function Movement:init(player)
	player.jump = false
	player.jumpSpeed = -250
	player.gravity = 700
	player.vy = 0
	player.jumpHeight = 0
	player.directionX = 0
	player.directionY = 0
	
	player.canJump = true
	player.jumpCooldown = 0.5
	player.jumpTimer = 0

	-- Dodane flagi do obsługi sterowania dotykowego (z controls.lua)
	player.moveLeft = false
	player.moveRight = false
	player.moveUp = false
	player.moveDown = false
end

function Movement:update(player, dt)
	-- Cooldown skoku
	if not player.canJump then
		player.jumpTimer = player.jumpTimer - dt
		if player.jumpTimer <= 0 then player.canJump = true end
	end

	local vx, vy = 0, 0
	local isMoving = false
	local currentSpeed = player.speed

	-- Klawisze (zakładam że GetBoundKey jest globalne)
	local UpKey = GetBoundKey("Up") or "w"
	local DownKey = GetBoundKey("Down") or "s"
	local LeftKey = GetBoundKey("Left") or "a"
	local RightKey = GetBoundKey("Right") or "d"
	local SprintKey = GetBoundKey("Sprint") or "lshift"

	-- === NOWA LOGIKA RUCHU (KLAWIATURA I DOTYK) ===
	
	-- Kierunki poziome
	if love.keyboard.isDown(RightKey) or player.moveRight then 
		vx = vx + 1; 
		player.anim = player.animations.right; 
		isMoving = true 
	end
	if love.keyboard.isDown(LeftKey) or player.moveLeft then 
		vx = vx - 1; 
		player.anim = player.animations.left; 
		isMoving = true 
	end
	
	-- Kierunki pionowe
	if love.keyboard.isDown(UpKey) or player.moveUp then 
		vy = vy - 1; 
		player.anim = player.animations.up; 
		isMoving = true 
	end
	if love.keyboard.isDown(DownKey) or player.moveDown then 
		vy = vy + 1; 
		player.anim = player.animations.down; 
		isMoving = true 
	end
	
	-- =============================================

	-- Normalizacja wektora
	local len = math.sqrt(vx*vx + vy*vy)
	if len > 0 then vx = vx / len; vy = vy / len end

	-- Sprint logic
	local isSprinting = love.keyboard.isDown(SprintKey) and player.stamina > 0
	local finalSpeed = currentSpeed
	
	if isSprinting then
		local sprintMultiplier = 650 / player.baseSpeed
		finalSpeed = currentSpeed * sprintMultiplier
		player.stamina = math.max(0, player.stamina - player.staminaDrain * dt)
	else
		player.stamina = math.min(player.maxStamina, player.stamina + player.staminaRegen * dt)
	end

	-- Obsługa fizyki skoku vs chodzenia
	if player.jump then
		player.vy = player.vy + player.gravity * dt
		player.jumpHeight = player.jumpHeight + player.vy * dt
		local nx = player.collider:getX() + player.directionX * finalSpeed * 0.05 * dt
		player.collider:setX(nx)
		
		if player.jumpHeight >= 0 then
			player.jumpHeight = 0
			player.vy = 0
			player.jump = false
		end
	else
		player.collider:setLinearVelocity(vx * finalSpeed, vy * finalSpeed)
	end

	-- Aktualizacja animacji spoczynkowej
	if not isMoving then
		player.anim:gotoFrame(2)
	end
	
	return isMoving -- zwracamy info czy się rusza, może się przydać
end

function Movement:tryJump(player)
	if not player.jump and player.canJump then
		local vx, vy = 0, 0
		local UpKey = GetBoundKey("Up") or "w"
		local DownKey = GetBoundKey("Down") or "s"
		local LeftKey = GetBoundKey("Left") or "a"
		local RightKey = GetBoundKey("Right") or "d"
		
		-- === Ważne: W tryJump również uwzględniamy flagi ruchu dotykowego ===
		if love.keyboard.isDown(UpKey) or player.moveUp then vy = -1 end
		if love.keyboard.isDown(DownKey) or player.moveDown then vy = 1 end
		if love.keyboard.isDown(LeftKey) or player.moveLeft then vx = -1 end
		if love.keyboard.isDown(RightKey) or player.moveRight then vx = 1 end
		-- ===================================================================

		player.jump = true
		player.vy = player.jumpSpeed
		player.directionX = vx
		player.directionY = vy
		player.jumpHeight = -0.0001
		player.canJump = false
		player.jumpTimer = player.jumpCooldown
	end
end

return Movement