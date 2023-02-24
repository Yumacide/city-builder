local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(script.Parent.MapConfig)

local getNoise = require(script.Parent.GetNoise)

local BIOME_MAP = require(script.Parent.BiomeMap)
local BIOME_TABLE = {
	[1] = { "Snow", "Snow" },
	[2] = { "Snow", "LightSnow" },
	[3] = { "Plains", "Green" },
	[4] = { "Plains", "LightGreen" },
	[5] = { "Desert", "Sand" },
}
local CHUNK_COUNT = 4

local MapFolder = workspace.Map

type Tile = {
	Biome: string,
	Height: number,
	Level: string,
}

local TreeModel = ReplicatedStorage.Assets.TreeModel

local WorldMap = {}
WorldMap.__index = WorldMap

-- Evaluate the falloff from a given value
local function evaluate(value: number)
	local a = 3
	local b = 2.2
	return value ^ a / (value ^ a + (b - b * value) ^ a)
end

local function getBiome(humidity: number, temperature: number)
	local x = math.clamp(math.round(100 * (1 - temperature)), 1, 100)
	local y = math.clamp(math.round(100 * (1 - humidity)), 1, 100)
	local biomeIndex = BIOME_MAP[x + (y - 1) * 100]
	if not biomeIndex then
		error(`${x} ${y} ${humidity} ${temperature}`)
	end

	return MapConfig.Biomes[BIOME_TABLE[biomeIndex][1]].Levels[BIOME_TABLE[biomeIndex][2]],
		BIOME_TABLE[biomeIndex][1],
		BIOME_TABLE[biomeIndex][2]
end

local function generateFalloff(width: number): { number }
	local map = table.create(width ^ 2)
	for i = 1, width do
		for j = 1, width do
			local x = i * 2 / width - 1
			local z = j * 2 / width - 1
			map[i + (j - 1) * width] = evaluate(math.max(math.abs(x), math.abs(z)))
		end
	end
	return map
end

local function resize(part: Part, size: number)
	part.Position += Vector3.new(0, 0, math.abs(part.Size.Z - size) / 2)
	part.Size = Vector3.new(1, 1, size)
end

local function drawOcean(origin: Vector3, width: number, height: number)
	local part = Instance.new("Part")
	part.Size = Vector3.new(width * 10, 1, height * 10)
	part.Anchored = true
	part.Position = origin + Vector3.new(width / 2, -1.01, height / 2)
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Color = Color3.fromRGB(87, 132, 215)
	part.Name = "Ocean"
	part.Parent = workspace.Map
end

function WorldMap.new(origin: Vector3, width: number, height: number)
	local self = setmetatable({}, WorldMap)

	self.origin = origin
	self.width = width
	self.height = height
	self.seed = Random.new():NextNumber(1, 100000)
	self.data = table.create(width * height) :: { Tile }
	self.falloffMap = generateFalloff(width)
	self._partCount = 0

	return self
end

function WorldMap.Get(self: WorldMap, x: number, z: number)
	return self.data[x + (z - 1) * self.width]
end
function WorldMap.Set(self: WorldMap, x: number, z: number, value: Tile)
	self.data[x + (z - 1) * self.width] = value
end

-- Get temperature as a function of distance from the equator
function WorldMap.GetTemperature(self: WorldMap, y: number)
	local a = 5
	local b = 4
	local distance = 0.5 - y / self.height
	return -b * math.exp(-a * distance) / (1 + math.exp(-a * distance)) ^ 2 + 1
end

function WorldMap.IsWalkable(self: WorldMap, x: number, z: number): boolean
	local tile = self:Get(x, z)
	local biome = tile.Biome
	local level = tile.Level
	return not MapConfig.Biomes[biome].Levels[level].Impassable
end

function WorldMap._DrawTree(self: WorldMap, x: number, z: number)
	local tree: Model = TreeModel:Clone()
	tree:PivotTo(CFrame.new(self.origin + Vector3.new(x, 1.5, z)))
	self.featureMap[x][z] = tree
	tree.Parent = workspace.Map.Features
end

function WorldMap._Draw(self: WorldMap, x: number, z: number)
	local tile = self:Get(x, z)
	local leftTile = self:Get(x, z - 1)

	if tile.Height <= -0.45 then
		tile.Part = workspace.Map.Ocean
		tile.IsOcean = true
		return
	end

	if
		leftTile
		and tile.Biome == leftTile.Biome
		and tile.Level == leftTile.Level
		and not MapConfig.Biomes[tile.Biome].Levels[tile.Level].NotGreedy
		and not leftTile.IsOcean
	then
		-- Extend previous part
		resize(leftTile.Part, leftTile.Part.Size.Z + 1)
		tile.Part = leftTile.Part
	else
		local part = Instance.new("Part")
		part.Size = Vector3.one
		part.Anchored = true
		part.CastShadow = false
		part.Position = self.origin + Vector3.new(x, 0, z)
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.TopSurface = Enum.SurfaceType.Smooth

		MapConfig.Biomes[tile.Biome].Levels[tile.Level].Modify(part, tile.Height)
		tile.Part = part
		self._partCount += 1
	end
end

function WorldMap.SnapToGrid(self: WorldMap, position: Vector3)
	return Vector3.new(
		math.round(math.clamp(position.X, self.origin.X, self.origin.X + self.width)),
		position.Y,
		math.round(math.clamp(position.Z, self.origin.Z, self.origin.Z + self.height))
	)
end

function WorldMap.GenerateHumidity(self: WorldMap)
	local map = table.create(self.width * self.height)
	for chunk = 1, CHUNK_COUNT do
		-- LEFT HERE
	end
end

function WorldMap.Generate(self: WorldMap)
	MapFolder:SetAttribute("Origin", self.origin)
	MapFolder:SetAttribute("Width", self.width)
	MapFolder:SetAttribute("Height", self.height)
	MapFolder:SetAttribute("Seed", self.seed)

	drawOcean(self.origin, self.width, self.height)

	for x = 1, self.width do
		for z = 1, self.height do
			local humidity = math.clamp(getNoise({ self.seed, x / 40, z / 40 }, 1) + 0.5, 0, 1)
			local temperature = math.clamp(
				self:GetTemperature(z), --+ getNoise({ math.round(math.sqrt(self.seed)), x / 40, z / 40 }, 0.1),
				0,
				1
			)
			local height = getNoise({ self.seed, x / 40, z / 40 }, 1, 2, 0.5)
				- self.falloffMap[x + (z - 1) * self.width]

			local biome, biomeName, levelName = getBiome(humidity, temperature)
			local tile = { Biome = biomeName, Height = height, Level = levelName }
			self:Set(x, z, tile)
			self:_Draw(x, z)
			if tile.Part.Name == "Ocean" then
				continue
			end
			tile.Part.Parent = workspace.Map.Tiles
		end
		if x % 20 == 0 then
			task.wait()
		end
	end

	self.falloffMap = nil
end

-- WorldPos must be at the center of a tile.
function WorldMap.GridPosFromWorldPos(self: WorldMap, worldPos: Vector3)
	return Vector2int16.new(
		math.clamp(worldPos.X - self.origin.X, 1, self.width),
		math.clamp(worldPos.Z - self.origin.Z, 1, self.height)
	)
end

function WorldMap.WorldPosFromGridPos(self: WorldMap, gridPos: Vector2int16)
	return self.origin + Vector3.new(gridPos.X, 0, gridPos.Y)
end

export type WorldMap = typeof(WorldMap.new(Vector3.zero, 0, 0))

return WorldMap
