local WorldMap = require(script.WorldMap)

local map = WorldMap.new(Vector3.new(0, 1, 0), 250, 250)
map:Generate()
warn("Part count: " .. map._partCount)
