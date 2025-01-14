local serpent = require 'serpent'

local wooshSound = love.audio.newSource("woosh.wav", "static")
local hitSound = love.audio.newSource("slap.wav", "static")

local grid = {}
local blockSize = 20
local gridWidth = 10
local gridHeight = 20
local shapes = {
    {{1, 1, 1, 1}}, -- I
    {{1, 1}, {1, 1}}, -- O
    {{0, 1, 0}, {1, 1, 1}}, -- T
    {{1, 1, 0}, {0, 1, 1}}, -- S
    {{0, 1, 1}, {1, 1, 0}} -- Z
}
local currentShape
local shapeX, shapeY
local dropTimer = 0
local dropInterval = 0.5
local keyPressDelay = 0.1
local keyPressTimers = {left = 0, right = 0, down = 0, up = 0}
local animations = {}

function love.load()
    for y = 1, gridHeight do
        grid[y] = {}
        for x = 1, gridWidth do
            grid[y][x] = 0
        end
    end
    newShape()
end

function newShape()
    currentShape = shapes[love.math.random(#shapes)]
    shapeX = math.floor(gridWidth / 2) - math.floor(#currentShape[1] / 2)
    shapeY = 1
end

function canMove(newX, newY)
    for y = 1, #currentShape do
        for x = 1, #currentShape[y] do
            if currentShape[y][x] == 1 then
                local gridX = newX + x
                local gridY = newY + y
                if gridX < 1 or gridX > gridWidth or gridY > gridHeight or grid[gridY][gridX] == 1 then
                    return false
                end
            end
        end
    end
    return true
end

function lockShape()
    for y = 1, #currentShape do
        for x = 1, #currentShape[y] do
            if currentShape[y][x] == 1 then
                grid[shapeY + y][shapeX + x] = 1
            end
        end
    end
    clearLines()
    newShape()
end

function clearLines()
    for y = gridHeight, 1, -1 do
        local full = true
        for x = 1, gridWidth do
            if grid[y][x] == 0 then
                full = false
                break
            end
        end
        if full then
            table.insert(animations, {y = y, alpha = 1})
            table.remove(grid, y)
            table.insert(grid, 1, {})
            for x = 1, gridWidth do
                grid[1][x] = 0
            end
            hitSound:play()
        end
    end
end

function love.update(dt)
    dropTimer = dropTimer + dt
    if dropTimer >= dropInterval then
        dropTimer = 0
        if canMove(shapeX, shapeY + 1) then
            shapeY = shapeY + 1
        else
            lockShape()
        end
    end

    if love.keyboard.isDown("s") then
        saveGame()
    elseif love.keyboard.isDown("l") then
        loadGame()
    elseif love.keyboard.isDown("left") and keyPressTimers.left <= 0 and canMove(shapeX - 1, shapeY) then
        shapeX = shapeX - 1
        keyPressTimers.left = keyPressDelay
    elseif love.keyboard.isDown("right") and keyPressTimers.left <= 0 and canMove(shapeX + 1, shapeY) then
        shapeX = shapeX + 1
        keyPressTimers.left = keyPressDelay
    elseif love.keyboard.isDown("down") and keyPressTimers.left <= 0 and canMove(shapeX, shapeY + 1) then
        shapeY = shapeY + 1
        keyPressTimers.left = keyPressDelay
    elseif love.keyboard.isDown("up") and keyPressTimers.up <= 0 then
        local newShape = rotateShape(currentShape)
        if canMove(shapeX, shapeY, newShape) then
            currentShape = newShape
        end
        keyPressTimers.up = keyPressDelay
    end

    for key, timer in pairs(keyPressTimers) do
        keyPressTimers[key] = timer - dt
    end

    updateAnimations(dt)
end

function love.draw()
    for y = 1, gridHeight do
        for x = 1, gridWidth do
            if grid[y][x] == 1 then
                love.graphics.rectangle("fill", (x - 1) * blockSize, (y - 1) * blockSize, blockSize, blockSize)
            else
                love.graphics.rectangle("line", (x - 1) * blockSize, (y - 1) * blockSize, blockSize, blockSize)
            end
        end
    end
    for y = 1, #currentShape do
        for x = 1, #currentShape[y] do
            if currentShape[y][x] == 1 then
                love.graphics.rectangle("fill", (shapeX + x - 1) * blockSize, (shapeY + y - 1) * blockSize, blockSize, blockSize)
            end
        end
    end

    drawAnimations()
end

function rotateShape(shape)
    local newShape = {}
    for x = 1, #shape[1] do
        newShape[x] = {}
        for y = 1, #shape do
            newShape[x][y] = shape[#shape - y + 1][x]
            wooshSound:play()
        end
    end
    return newShape
end

function saveGame()
    local data = {
        grid = grid,
        currentShape = currentShape,
        shapeX = shapeX,
        shapeY = shapeY
    }
    local serializedData = serpent.dump(data)
    love.filesystem.write("savegame.dat", serializedData)
end

function loadGame()
    if love.filesystem.getInfo("savegame.dat") then
        local serializedData = love.filesystem.read("savegame.dat")
        local data = assert(loadstring(serializedData))()
        grid = data.grid
        currentShape = data.currentShape
        shapeX = data.shapeX
        shapeY = data.shapeY
    end
end

function updateAnimations(dt)
    for i = #animations, 1, -1 do
        local anim = animations[i]
        anim.alpha = anim.alpha - dt
        if anim.alpha <= 0 then
            table.remove(animations, i)
        end
    end
end

function drawAnimations()
    for _, anim in ipairs(animations) do
        love.graphics.setColor(196, 129, 240, anim.alpha)
        love.graphics.rectangle("fill", 0, (anim.y - 1) * blockSize, gridWidth * blockSize, blockSize)
    end
    love.graphics.setColor(1, 1, 1, 1)
end
