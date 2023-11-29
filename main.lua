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

-- buffer size, sampling rate, bit depth, channel count, internal OpenALSoft buffers
local samplerate = 48000
local sounddata = love.sound.newSoundData(2048, samplerate, 16, 1)
local qsource = love.audio.newQueueableSource(samplerate, 16, 1, 2)
local voice = {} -- list of playing sounds

-- call this in the sorting code
local function triggerSound(val, maxval)
  local norm = (val / maxval)                   -- [0,1]
  local pitch = 220 + 2 ^ (norm * 12 / 12)      -- restrict to one octave, but it does simplify, unless i messed it up
  local new = {
    phase   = love.math.random() * 2 * math.pi, -- this helps with lots of overlapping sounds
    pitch   = pitch,                            -- pitch of the sound, when sorted, it should sound neat and in order
    active  = true,                             -- if set to false, it won't play, can get reused
    length  = 0.5,                              -- duration of sound in seconds
    counter = 0.0
  }
  for i, v in ipairs(voice) do
    if not v.active then
      voice[i] = new
      return
    end
  end
  table.insert(voice, new)
end

-- synthesizes and mixes audio
local function renderSound()
  for i = 0, sounddata:getSampleCount() - 1 do
    local smp = 0.0
    for _, v in ipairs(voice) do
      if v.active then
        v.counter = v.counter - 1 / samplerate
        if v.counter >= v.length then
          v.active = false
        else
          local amp = math.sin(v.counter / v.length * math.pi) -- nice curve for fading in and out the sound
          local phi = math.sin(v.phase * math.pi * 2 / samplerate)
          smp = smp + phi * amp
          v.phase = v.phase + v.pitch / samplerate
        end
      end
    end
    sounddata:setSample(i, smp)
  end
  return sounddata
end

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
      triggerSound(i, numValues)
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

  if qsource:getFreeBufferCount() > 0 then
    qsource:queue(renderSound())
    qsource:play()
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
