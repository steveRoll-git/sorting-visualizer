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
  local norm = ((val - 1) / (maxval - 1)))      -- [0,1]
  norm = norm * 12                              -- restrict all values to one octave
  local pitch = 440.00 * (2 ^ (norm / 12))   -- restrict to one octave, but it does simplify, unless i messed it up
  local new = {
    phase   = love.math.random() * 2 * math.pi, -- this helps with lots of overlapping sounds
    pitch   = pitch,                            -- pitch of the sound, when sorted, it should sound neat and in order
    active  = true,                             -- if set to false, it won't play, can get reused
    length  = 0.04,                             -- duration of sound in seconds
    counter = 0.0                               -- internals
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
    for j, v in ipairs(voice) do
      if v.active then
        voice[j].counter = v.counter + 1 / samplerate
        if v.counter >= v.length then
          voice[j].active = false
        else
          -- amplitude
          local amp = math.sin(v.counter / v.length * math.pi) -- sinusoidal envelope
          --local amp = (v.counter / v.length) < 0.5 and (v.counter / v.length * 2) or ((0.5 - (v.counter / v.length)) * 2) -- triangular envelope, not the best

          -- waveform
          --local phi = math.sin(v.phase * math.pi * 2) -- sine wave
          local phi = v.phase < 0.5 and -1.0 or 1.0     -- square wave

          smp = smp + phi * amp
          v.phase = (v.phase + v.pitch / samplerate) % 1.0
        end
      end
    end
    smp = smp / (numValues / 2) -- attenuation to keep sound volume consistent
    smp = math.max(math.min(smp, 1.0), -1.0)
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
      triggerSound(values[i], numValues)
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

  while qsource:getFreeBufferCount() > 0 do
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
