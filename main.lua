local love = love
local lg = love.graphics

local iterationsPerFrame = 4

local numValues = 100

local values

local lastIndexes = {}
local runner
local finished

local currentAlgoIndex = 1
local currentAlgo

local algorithms = {}

for _, v in ipairs(love.filesystem.getDirectoryItems("algorithms")) do
  local name = v:match("(%w+)%.lua")
  table.insert(algorithms, {
    name = name,
    func = require("algorithms." .. name)
  })
end

local function initialize(algo)
  currentAlgo = algo

  values = {}
  for i = 1, numValues do
    table.insert(values, love.math.random(1, #values + 1), i)
  end

  runner = coroutine.create(algo.func)
  finished = false
  coroutine.resume(runner, {
    length = numValues,
    read = function(i)
      lastIndexes[i] = true
      coroutine.yield()
      return values[i]
    end,
    swap = function(i, j)
      lastIndexes[i] = true
      lastIndexes[j] = true
      coroutine.yield()
      values[i], values[j] = values[j], values[i]
    end
  })
end

initialize(algorithms[currentAlgoIndex])

function love.update(dt)
  if values and not finished then
    lastIndexes = {}
    for i = 1, iterationsPerFrame do
      coroutine.resume(runner)
      if coroutine.status(runner) == "dead" then
        break
      end
    end
    finished = coroutine.status(runner) == "dead"
  end
end

function love.keypressed(key)
  if key == "r" then
    initialize(algorithms[currentAlgoIndex])
  elseif key == "right" then
    currentAlgoIndex = currentAlgoIndex + 1
    if currentAlgoIndex > #algorithms then
      currentAlgoIndex = 1
    end
    initialize(algorithms[currentAlgoIndex])
  elseif key == "left" then
    currentAlgoIndex = currentAlgoIndex - 1
    if currentAlgoIndex < 1 then
      currentAlgoIndex = #algorithms
    end
    initialize(algorithms[currentAlgoIndex])
  end
end

function love.draw()
  if values then
    local barWidth = lg.getWidth() / numValues
    for index, value in ipairs(values) do
      lg.push()
      lg.translate((index - 1) * barWidth, lg.getHeight())
      if not finished and lastIndexes[index] then
        lg.setColor(1, 0, 0)
      else
        lg.setColor(1, 1, 1)
      end
      lg.rectangle("fill", 0, 0, barWidth, -(value / numValues * lg.getHeight()))
      lg.pop()
    end
  end

  lg.setColor(1, 1, 1)
  lg.print(currentAlgo.name)
end
