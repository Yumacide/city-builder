local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapFolder = workspace.Map

-- TODO: make a separate noise map for trees
-- TODO: make island object that contains all the tiles
-- TODO: make map class to encapsulate all the map stuff
type Map2D<T> = { { T } }

local TREE_THRESHOLD, GRASS_THRESHOLD, SAND_THRESHOLD, SHORE_THRESHOLD = 0.25, 0, -0.1, -0.2

local TreeModel = ReplicatedStorage.Assets.TreeModel

local WorldMap = {}
WorldMap.__index = WorldMap

-- Evaluate the falloff from a given value
local function evaluate(value: number)
	local a = 3
	local b = 2.2
	return value ^ a / (value ^ a + (b - b * value) ^ a)
end

local function generateFalloff(size: number): Map2D<number>
	local map = table.create(size)
	for i = 1, size do
		map[i] = table.create(size)
		for j = 1, size do
			local x = i * 2 / size - 1
			local z = j * 2 / size - 1
			map[i][j] = evaluate(math.max(math.abs(x), math.abs(z)))
		end
	end
	return map
end

local function resize(part: Part, size: number)
	part.Position = part.Position + Vector3.new(0, 0, math.abs(part.Size.Z - size) / 2)
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
	self.noiseMap = table.create(width)
	self.tileMap = table.create(width)
	self.featureMap = table.create(width)
	self.falloffMap = generateFalloff(width)
	self._partCount = 0

	return self
end

function WorldMap._DrawTree(self: WorldMap, x: number, z: number)
	local tree: Model = TreeModel:Clone()
	tree:PivotTo(CFrame.new(self.origin + Vector3.new(x, 1.5, z)))
	self.featureMap[x][z] = tree
	tree.Parent = workspace.Map.Features
end

function WorldMap._Draw(self: WorldMap, x: number, z: number)
	local terrainIndex = self.noiseMap[x][z]

	if terrainIndex == 5 then
		self.tileMap[x][z] = workspace.Map.Ocean
		return
	end

	if self.noiseMap[x][z - 1] == terrainIndex then
		-- Extend previous part
		local previousPart = self.tileMap[x][z - 1]
		resize(previousPart, previousPart.Size.Z + 1)
		self.tileMap[x][z] = previousPart
		if terrainIndex == 4 then
			self:_DrawTree(x, z)
		end
	else
		local part = Instance.new("Part")
		part.Size = Vector3.one
		part.Anchored = true
		part.CastShadow = false
		part.Position = self.origin + Vector3.new(x, 0, z)
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.TopSurface = Enum.SurfaceType.Smooth

		if terrainIndex == 1 then
			part.Color = Color3.fromRGB(107, 215, 116)
		elseif terrainIndex == 2 then
			part.Color = Color3.fromRGB(227, 216, 182)
		elseif terrainIndex == 3 then
			part.Color = Color3.fromRGB(133, 171, 243)
			part.Position -= Vector3.new(0, 1, 0)
		elseif terrainIndex == 4 then
			part.Color = Color3.fromRGB(107, 215, 116)
			self:_DrawTree(x, z)
		end

		self.tileMap[x][z] = part
		self._partCount += 1
	end
end

function WorldMap.Generate(self: WorldMap)
	MapFolder:SetAttribute("Origin", self.origin)
	MapFolder:SetAttribute("Width", self.width)
	MapFolder:SetAttribute("Height", self.height)
	MapFolder:SetAttribute("Seed", self.seed)

	drawOcean(self.origin, self.width, self.height)

	for x = 1, self.width do
		self.noiseMap[x] = table.create(self.height)
		self.tileMap[x] = table.create(self.height)
		self.featureMap[x] = table.create(self.height)
		for z = 1, self.height do
			local noise = math.noise(self.seed, x / 40, z / 40) - self.falloffMap[x][z]
			self.noiseMap[x][z] = if noise > TREE_THRESHOLD
				then 4
				elseif noise > GRASS_THRESHOLD then 1
				elseif noise > SAND_THRESHOLD then 2
				elseif noise > SHORE_THRESHOLD then 3
				else 5
			self:_Draw(x, z)
		end
		if x % 20 == 0 then
			task.wait()
		end
	end

	for x = 1, self.width do
		for z = 1, self.height do
			self.tileMap[x][z].Parent = workspace.Map.Tiles
		end
		if x % 20 == 0 then
			task.wait()
		end
	end
end

type WorldMap = typeof(WorldMap.new(Vector3.zero, 0, 0))

return WorldMap
