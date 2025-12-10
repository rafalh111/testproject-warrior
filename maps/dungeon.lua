local roomTypes = require("roomTypes")

local dungeon = {}

-- Dungeon module
-- This module procedurally generates square "chunks" made of tiles using
-- a BSP (binary space partitioning) algorithm to carve rooms and corridors.
-- It also converts wall tiles into rectangular objects, caches chunks to
-- disk (`chunks/`), and can create physics colliders when a physics world
-- is provided.

-- External libraries
local serpent = require("libraries/serpent")
local structures = require("structures") 

-- Zmienne prywatne modułu

-- Private state for the module
-- `physicsWorld` is set externally so the dungeon can create colliders.
local physicsWorld = nil 

-- Tables used as caches / stores indexed by chunk coordinates `cx` then `cy`:
-- `colliders` : physics collider rectangles per chunk
-- `chunks`    : tile maps (1D arrays) per chunk
-- `objectLayers`: object layers (e.g. generated wall objects) per chunk
-- `structuresOnMap`: placed structure instances per chunk
dungeon.colliders = {}      
dungeon.chunks = {}         
dungeon.objectLayers = {}   
dungeon.structuresOnMap = {}
dungeon.roomsOnMap = {}  -- indexed by [cx][cy]



-- KONFIGURACJA
-- CONFIGURATION
-- `CHUNK_SIZE` : number of tiles per side of a square chunk (chunk is CHUNK_SIZE x CHUNK_SIZE)
local CHUNK_SIZE = 64
-- `TILE_SIZE` : pixel size of a single tile (used for converting tile coords to world pixels)
local TILE_SIZE  = 64
-- corridor thickness in tiles
local CORRIDOR_WIDTH = 3
-- base seed for deterministic per-chunk RNG
local CHUNK_SEED = os.time()

-- Tile IDs (these are the values written into the tile map array)
local WALL  = 0
local FLOOR = 384


-- PUBLICZNE FUNKCJE MODUŁU
-- Set the physics world used to create colliders. Pass a Windfield/HC world.
function dungeon.setPhysicsWorld(world)
    physicsWorld = world
end

-- Return a flat list of all wall collider objects currently loaded.
function dungeon.getAllWalls()
    local allWalls = {}
    for cx, chunkY in pairs(dungeon.colliders) do
        for cy, wallsList in pairs(chunkY) do
            for _, wall in ipairs(wallsList) do
                table.insert(allWalls, wall) 
            end
        end
    end
    return allWalls
end


-- WŁAŚCIWE OBIEKTY FIZYCZNE (DLA HC/Windfield)
-- Create physics colliders for the wall objects in the chunk (if a physics
-- world has been set). Returns a list of collider wrappers for the chunk.
function dungeon.loadChunkPhysics(cx, cy)
    if not physicsWorld then return {} end 
    -- ensure chunk exists (loads or generates it)
    dungeon.getChunk(cx, cy) 
    
    dungeon.colliders[cx] = dungeon.colliders[cx] or {}
    if dungeon.colliders[cx][cy] then return dungeon.colliders[cx][cy] end

    local wallsData = dungeon.getChunkObjects(cx, cy)
    local chunkWalls = {}

    -- Convert each wall object into a physics collider and store metadata
    for _, obj in ipairs(wallsData) do
        local wall = {
            x = obj.x, y = obj.y,
            w = obj.width, h = obj.height,
            collider = physicsWorld:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
        }
        wall.collider:setType("static")
        wall.collider:setCollisionClass("Wall")
        table.insert(chunkWalls, wall)
    end
    
    dungeon.colliders[cx][cy] = chunkWalls
    return chunkWalls
end

-- Called each frame (or when the player moves) to ensure nearby chunks are
-- generated/loaded and their physics colliders exist. Loads a 3x3 area around
-- the chunk that contains the player.
function dungeon.update(playerX, playerY) 
    local tx = math.floor(playerX / TILE_SIZE)
    local ty = math.floor(playerY / TILE_SIZE)

    local cx = math.floor(tx / CHUNK_SIZE)
    local cy = math.floor(ty / CHUNK_SIZE)

    -- Preload neighbouring chunks and their physics
    for y = -1,1 do
        for x = -1,1 do
            dungeon.getChunk(cx + x, cy + y) 
            dungeon.loadChunkPhysics(cx + x, cy + y) 
        end
    end
end


-- BSP LEAF
-- BSP Leaf: used to recursively split a chunk into sub-regions and carve rooms
Leaf = {}
Leaf.__index = Leaf

function Leaf:new(x, y, w, h, depth)
    local l = setmetatable({}, Leaf)
    l.x, l.y, l.width, l.height = x, y, w, h
    l.leftChild, l.rightChild = nil, nil
    l.room = nil
    l.depth = (depth or 0) + 1
    return l
end

function Leaf:split(minSize)
    if self.leftChild or self.rightChild then return false end
    if self.depth > 5 then return false end

    local splitH = math.random(0,1) == 1
    if self.width > self.height then splitH = false end
    if self.height > self.width then splitH = true end

    local max = splitH and (self.height - minSize) or (self.width - minSize)
    if max <= minSize then return false end

    local split = math.random(minSize, max)

    if splitH then
        self.leftChild  = Leaf:new(self.x, self.y, self.width, split, self.depth)
        self.rightChild = Leaf:new(self.x, self.y + split, self.width, self.height - split, self.depth)
    else
        self.leftChild  = Leaf:new(self.x, self.y, split, self.height, self.depth)
        self.rightChild = Leaf:new(self.x + split, self.y, self.width - split, self.height, self.depth)
    end

    return true
end

function Leaf:createRoom()
    if self.leftChild or self.rightChild then
        if self.leftChild then self.leftChild:createRoom() end
        if self.rightChild then self.rightChild:createRoom() end
        return
    end

    local roomRoulette = {}
    for name, rt in pairs(roomTypes) do
        local tickets = math.max(1, rt.rouletteTickets or 1)
        for i = 1, tickets do
            table.insert(roomRoulette, name)
        end
    end

    local chosenTypeName = roomRoulette[math.random(#roomRoulette)]
    local baseType = roomTypes[chosenTypeName]

    local rw = math.random(6, self.width - 2)
    local rh = math.random(6, self.height - 2)
    local rx = math.random(self.x + 1, self.x + self.width - rw - 1)
    local ry = math.random(self.y + 1, self.y + self.height - rh - 1)

    self.room = {
        type = chosenTypeName,
        x = rx,
        y = ry,
        width = rw,
        height = rh,
        structures = baseType.structures
    }
end


function Leaf:getRooms()
    local r = {}
    if self.room then table.insert(r, self.room) end
    if self.leftChild then
        for _,v in ipairs(self.leftChild:getRooms()) do table.insert(r,v) end
    end
    if self.rightChild then
        for _,v in ipairs(self.rightChild:getRooms()) do table.insert(r,v) end
    end
    return r
end

-- Notes on BSP usage:
-- 1. We create a root Leaf covering the entire chunk (1..CHUNK_SIZE)
-- 2. We repeatedly split leaves until no more splits are possible.
-- 3. We call `createRoom` on leaves (which picks a room inside each leaf)
-- 4. Rooms are connected in the order returned by `getRooms` using corridors.


-- FUNKCJE POMOCNICZE
-- Helper: set a deterministic seed for a chunk using its coordinates.
local function setSeed(cx, cy)
    local seed = CHUNK_SEED + cx * 912931 + cy * 192837
    math.randomseed(seed)
end

-- Create an L-shaped corridor between the centers of two rooms.
-- The corridor has a thickness of `CORRIDOR_WIDTH` tiles. It chooses randomly
-- whether to go horizontal-then-vertical or vertical-then-horizontal.
local function createCorridor(map, w, roomA, roomB)
    local cw = CORRIDOR_WIDTH
    local hw = math.floor(cw / 2) -- half width for symmetric thickness
    
    local x1 = math.floor(roomA.x + roomA.width / 2)
    local y1 = math.floor(roomA.y + roomA.height / 2)
    local x2 = math.floor(roomB.x + roomB.width / 2)
    local y2 = math.floor(roomB.y + roomB.height / 2)

    -- Draw a single floor tile at chunk tile coords (tx,ty) after bounds check
    local function drawFloor(tx, ty)
        if tx >= 1 and tx <= w and ty >= 1 and ty <= w then
            map[(ty - 1) * w + tx] = FLOOR
        end
    end

    if math.random(0, 1) == 0 then
        -- horizontal from x1 to x2 at y1, then vertical to y2 at x2
        for x = math.min(x1, x2), math.max(x1, x2) do
            for y_offset = -hw, hw do
                drawFloor(x, y1 + y_offset)
            end
        end
        for y = math.min(y1, y2), math.max(y1, y2) do
            for x_offset = -hw, hw do
                drawFloor(x2 + x_offset, y)
            end
        end
    else
        -- vertical from y1 to y2 at x1, then horizontal to x2 at y2
        for y = math.min(y1, y2), math.max(y1, y2) do
            for x_offset = -hw, hw do
                drawFloor(x1 + x_offset, y)
            end
        end
        for x = math.min(x1, x2), math.max(x1, x2) do
            for y_offset = -hw, hw do
                drawFloor(x, y2 + y_offset)
            end
        end
    end
end

-- Create a corridor between two rooms using world tile coordinates
-- Supports corridors crossing multiple chunks
local function createWorldCorridor(roomA, cxA, cyA, roomB, cxB, cyB)
    local cw = CORRIDOR_WIDTH
    local hw = math.floor(cw / 2)

    -- Compute world tile coordinates for the centers of both rooms
    local wx1 = cxA * CHUNK_SIZE + math.floor(roomA.x + roomA.width / 2)
    local wy1 = cyA * CHUNK_SIZE + math.floor(roomA.y + roomA.height / 2)
    local wx2 = cxB * CHUNK_SIZE + math.floor(roomB.x + roomB.width / 2)
    local wy2 = cyB * CHUNK_SIZE + math.floor(roomB.y + roomB.height / 2)

    -- Helper to set a tile at world coords
    local function setTile(wx, wy, tile)
        local chunkX = math.floor(wx / CHUNK_SIZE)
        local chunkY = math.floor(wy / CHUNK_SIZE)
        local lx = (wx % CHUNK_SIZE) + 1
        local ly = (wy % CHUNK_SIZE) + 1
        local chunk = dungeon.getChunk(chunkX, chunkY)
        chunk[(ly-1)*CHUNK_SIZE + lx] = tile
    end

    -- Draw floor tiles along a path (horizontal then vertical or vice versa)
    if math.random(0,1) == 0 then
        -- horizontal then vertical
        for x = math.min(wx1, wx2), math.max(wx1, wx2) do
            for y_offset = -hw, hw do
                setTile(x, wy1 + y_offset, FLOOR)
            end
        end
        for y = math.min(wy1, wy2), math.max(wy1, wy2) do
            for x_offset = -hw, hw do
                setTile(wx2 + x_offset, y, FLOOR)
            end
        end
    else
        -- vertical then horizontal
        for y = math.min(wy1, wy2), math.max(wy1, wy2) do
            for x_offset = -hw, hw do
                setTile(wx1 + x_offset, y, FLOOR)
            end
        end
        for x = math.min(wx1, wx2), math.max(wx1, wx2) do
            for y_offset = -hw, hw do
                setTile(x, wy2 + y_offset, FLOOR)
            end
        end
    end
end

-- Convert contiguous wall tiles into as few rectangular wall objects as
-- possible. This scans the tile map, groups horizontal runs, and then tries
-- to extend them vertically to form larger rectangles. This reduces number of
-- objects/colliders needed.
local function generateWallsObjects(map, w, h, cx, cy)
    local walls = {}
    local visited = {}
    
    for y = 1, h do
        for x = 1, w do
            local index = (y - 1) * w + x
            if map[index] == WALL and not visited[index] then
                -- find maximal horizontal run starting at (x,y)
                local endX = x
                while endX < w do
                    local nextIndex = (y - 1) * w + (endX + 1)
                    if map[nextIndex] == WALL and not visited[nextIndex] then endX = endX + 1 else break end
                end

                local rectW = endX - x + 1
                local rectH = 1
                local endY = y
                -- try to extend the rectangle downward while all tiles below are free and unvisited
                while endY < h do
                    local canExtend = true
                    for checkX = x, endX do
                        local checkIndex = (endY) * w + checkX
                        if map[checkIndex] ~= WALL or visited[checkIndex] then canExtend = false; break end
                    end
                    if canExtend then endY = endY + 1; rectH = rectH + 1 else break end
                end
                
                -- mark area as visited so we don't create overlapping rectangles
                for markY = y, endY do
                    for markX = x, endX do
                        visited[(markY - 1) * w + markX] = true
                    end
                end

                table.insert(walls, {
                    name = "Wall", type = "Wall", shape = "rectangle",
                    x = (cx * w + x - 1) * TILE_SIZE, y = (cy * h + y - 1) * TILE_SIZE,
                    width = rectW * TILE_SIZE, height = rectH * TILE_SIZE,
                    visible = false, properties = {}
                })
            end
        end
    end
    
    return { name = "Walls", objects = walls }
end

-- Place predefined structures (from `structures` table) randomly inside rooms.
-- This returns a list of placed instances with world pixel coordinates.
local function placeStructures(rooms, cx, cy)
    local placed = {}

    for _, room in ipairs(rooms) do
        local rt = roomTypes[room.type]

        if rt and rt.structures then
            for i = 1, math.random(1, 5) do
                local key = rt.structures[math.random(#rt.structures)]

                table.insert(placed, {
                    name = key,
                    data = structures[key],
                    x = (cx * CHUNK_SIZE + math.random(room.x, room.x + room.width - 1)) * TILE_SIZE,
                    y = (cy * CHUNK_SIZE + math.random(room.y, room.y + room.height - 1)) * TILE_SIZE
                })
            end
        end
    end

    return placed
end

function stitchChunkToOthers(cx, cy)
    local directions = {
        {dx = -1, dy = 0},  -- left
        {dx =  1, dy = 0},  -- right
        {dx =  0, dy = -1}, -- up
        {dx =  0, dy =  1}  -- down
    }

    local function roomManhattanDistance(roomA, roomB)
        local ax = roomA.x + roomA.width / 2
        local ay = roomA.y + roomA.height / 2
        local bx = roomB.x + roomB.width / 2
        local by = roomB.y + roomB.height / 2
        return math.abs(ax - bx) + math.abs(ay - by)
    end

    local map = dungeon.chunks[cx][cy]

    for _, dir in ipairs(directions) do
        local nx, ny = cx + dir.dx, cy + dir.dy

        if dungeon.chunks[nx] and dungeon.chunks[nx][ny] and
           dungeon.roomsOnMap[cx] and dungeon.roomsOnMap[cx][cy] and
           dungeon.roomsOnMap[nx] and dungeon.roomsOnMap[nx][ny] then

            local closestCenterRooms = {}
            local closestSideRooms   = {}

            -- collect center rooms
            for _, room in ipairs(dungeon.roomsOnMap[cx][cy]) do
                local rx = room.x + room.width / 2
                local ry = room.y + room.height / 2
                local dist

                if dir.dx == -1 then dist = rx end
                if dir.dx ==  1 then dist = CHUNK_SIZE - rx end
                if dir.dy == -1 then dist = ry end
                if dir.dy ==  1 then dist = CHUNK_SIZE - ry end

                table.insert(closestCenterRooms, {room = room, d = dist})
            end

            -- collect side rooms
            for _, room in ipairs(dungeon.roomsOnMap[nx][ny]) do
                local rx = room.x + room.width / 2
                local ry = room.y + room.height / 2
                local dist

                if dir.dx == -1 then dist = CHUNK_SIZE - rx end
                if dir.dx ==  1 then dist = rx end
                if dir.dy == -1 then dist = CHUNK_SIZE - ry end
                if dir.dy ==  1 then dist = ry end

                table.insert(closestSideRooms, {room = room, d = dist})
            end

            table.sort(closestCenterRooms, function(a,b) return a.d < b.d end)
            table.sort(closestSideRooms,   function(a,b) return a.d < b.d end)

            while #closestCenterRooms > 3 do table.remove(closestCenterRooms) end
            while #closestSideRooms   > 3 do table.remove(closestSideRooms) end

            for i = 1, #closestCenterRooms do
                closestCenterRooms[i] = closestCenterRooms[i].room
            end
            for i = 1, #closestSideRooms do
                closestSideRooms[i] = closestSideRooms[i].room
            end

            -- match rooms by shortest manhattan distance
            for _, edgeCenterRoom in ipairs(closestCenterRooms) do
                local best = nil
                local bestDist = math.huge

                for _, edgeSideRoom in ipairs(closestSideRooms) do
                    local dist = roomManhattanDistance(edgeCenterRoom, edgeSideRoom)
                    if dist < bestDist then
                        best = edgeSideRoom
                        bestDist = dist
                    end
                end

                if best then
                    -- NOTE: this only works for SAME chunk carving
                    -- real cross-chunk corridors need a world-coord version
                    createWorldCorridor(edgeCenterRoom, cx, cy, best, nx, ny)
                end
            end
        end
    end
end

-- GENEROWANIE I CACHE
function dungeon.generateChunk(cx, cy)
    -- Generate a deterministic random layout for chunk (cx,cy)
    setSeed(cx, cy)
    local w, h = CHUNK_SIZE, CHUNK_SIZE

    -- start with all walls
    local map = {}
    for i=1,w*h do map[i] = WALL end

    -- create BSP tree and split until leaves are small enough
    local root = Leaf:new(1,1,w,h)
    local leaves = {root}
    local split = true
    while split do
        split = false
        for i=#leaves,1,-1 do
            if leaves[i]:split(6) then
                table.insert(leaves, leaves[i].leftChild); table.insert(leaves, leaves[i].rightChild)
                table.remove(leaves, i); split = true
            end
        end
    end

    -- carve rooms inside leaves
    root:createRoom()
    local rooms = root:getRooms()

    dungeon.roomsOnMap[cx] = dungeon.roomsOnMap[cx] or {}
    dungeon.roomsOnMap[cx][cy] = rooms
    
    for _,room in ipairs(rooms) do
        for y=room.y, room.y + room.height - 1 do
            for x=room.x, room.x + room.width - 1 do
                map[(y-1)*w + x] = FLOOR
            end
        end
    end

    -- connect rooms with corridors (simple method: connect sequential rooms)
    for i = 2, #rooms do createCorridor(map, CHUNK_SIZE, rooms[i-1], rooms[i]) end

    -- stitch corridors to neighbouring chunks
    stitchChunkToOthers(cx, cy)  -- ✅ Important

    -- place structures and create wall objects layer
    dungeon.structuresOnMap[cx] = dungeon.structuresOnMap[cx] or {}; dungeon.structuresOnMap[cx][cy] = placeStructures(rooms, cx, cy)
    local wallsLayer = generateWallsObjects(map, w, h, cx, cy)

    return map, wallsLayer
end

local currentlyGenerating = {} -- table to track chunks being generated

function dungeon.getChunk(cx, cy)
    dungeon.chunks[cx] = dungeon.chunks[cx] or {}
    dungeon.objectLayers[cx] = dungeon.objectLayers[cx] or {}

    if dungeon.chunks[cx][cy] then return dungeon.chunks[cx][cy] end

    -- Check if this chunk is currently generating (to prevent recursion)
    currentlyGenerating[cx] = currentlyGenerating[cx] or {}
    if currentlyGenerating[cx][cy] then
        -- Return a temporary all-wall map to prevent recursion
        local tempMap = {}
        for i = 1, CHUNK_SIZE*CHUNK_SIZE do tempMap[i] = WALL end
        return tempMap
    end

    currentlyGenerating[cx][cy] = true

    -- Disk loading (unchanged)
    if not love.filesystem.getInfo("chunks") then love.filesystem.createDirectory("chunks") end
    local file = "chunks/" .. cx .. "_" .. cy .. ".lua"
    if love.filesystem.getInfo(file) then
        local f = love.filesystem.load(file)
        local data = f()
        if data.map and data.walls then
            dungeon.chunks[cx][cy] = data.map
            dungeon.objectLayers[cx][cy] = data.walls
            currentlyGenerating[cx][cy] = nil
            return data.map
        end
    end

    -- Generate new chunk
    local map, wallsLayer = dungeon.generateChunk(cx, cy)
    dungeon.chunks[cx][cy] = map
    dungeon.objectLayers[cx][cy] = wallsLayer

    love.filesystem.write(file, "return " .. serpent.dump({ map = map, walls = wallsLayer }))

    currentlyGenerating[cx][cy] = nil

    return map
end


-- GETTERY (Dostęp do danych)
function dungeon.getTile(wx, wy)
    local tx = math.floor(wx / TILE_SIZE)
    local ty = math.floor(wy / TILE_SIZE)
    local cx = math.floor(tx / CHUNK_SIZE)
    local cy = math.floor(ty / CHUNK_SIZE)
    local lx = tx % CHUNK_SIZE + 1
    local ly = ty % CHUNK_SIZE + 1
    local chunk = dungeon.getChunk(cx, cy)
    return chunk[(ly - 1) * CHUNK_SIZE + lx]
end

function dungeon.getChunkObjects(cx, cy)
    dungeon.getChunk(cx, cy)
    if dungeon.objectLayers[cx] and dungeon.objectLayers[cx][cy] then
        return dungeon.objectLayers[cx][cy].objects
    end
    return {}
end

-- RYSOWANIE
function dungeon.draw(drawTile, playerX, playerY)
    local tx = math.floor(playerX / TILE_SIZE); local ty = math.floor(playerY / TILE_SIZE)
    local pcx = math.floor(tx / CHUNK_SIZE); local pcy = math.floor(ty / CHUNK_SIZE)

    for cy = pcy - 1, pcy + 1 do
        for cx = pcx - 1, pcx + 1 do
            local chunk = dungeon.getChunk(cx, cy)
            
            -- 1. Draw tiles: call the provided `drawTile(tile, x, y)` for each tile
            for y = 1, CHUNK_SIZE do
                for x = 1, CHUNK_SIZE do
                    local tile = chunk[(y-1)*CHUNK_SIZE + x]
                    drawTile(tile, (cx*CHUNK_SIZE + x-1) * TILE_SIZE, (cy*CHUNK_SIZE + y-1) * TILE_SIZE)
                end
            end

            -- 2. Draw placed structures (images). We cache images on the instance
            -- in `s.imageCached` so we don't recreate them every frame.
            if dungeon.structuresOnMap[cx] and dungeon.structuresOnMap[cx][cy] then
                for _, s in ipairs(dungeon.structuresOnMap[cx][cy]) do
                    -- Cache image once
                    if not s.imageCached then
                        s.imageCached = love.graphics.newImage(s.data.image)
                    end

                    local img = s.imageCached

                    -- Safe scale values
                    local sx = (s.data.intendedScale and s.data.intendedScale.x) or 1
                    local sy = (s.data.intendedScale and s.data.intendedScale.y) or 1

                    local w = img:getWidth()
                    local h = img:getHeight()

                    -- Draw bottom-center anchored, correctly scaled
                    love.graphics.draw(
                        img,
                        s.x, s.y,
                        0,
                        sx, sy,
                        w / 2,
                        h
                    )
                end
            end
        end
    end
end

return dungeon