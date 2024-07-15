local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathNode = require(script.Parent.PathNode)
local Building = require(script.Parent.Building)

local MapFolder = workspace.Map

type Map2D<T> = { { T } }

local TREE_THRESHOLD, GRASS_THRESHOLD, SAND_THRESHOLD, SHORE_THRESHOLD = 0.25, 0, -0.1, -0.2

local TerrainType = {
	Forest = 1,
	Grass = 2,
	Sand = 3,
	Shore = 4,
	Ocean = 5,
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

local function reverse(t: { any })
	local reversed = {}
	for i = #t, 1, -1 do
		table.insert(reversed, t[i])
	end
	return reversed
end

function WorldMap.new(origin: Vector3, width: number, height: number)
	local self = setmetatable({}, WorldMap)

	self.origin = origin
	self.width = width
	self.height = height
	self.seed = Random.new():NextNumber(1, 100000)
	self.tileMap = table.create(width)
	self.terrainMap = table.create(width)
	self.featureMap = table.create(width)
	self.buildingMap = table.create(width) :: { { Building.Building } }
	self.falloffMap = generateFalloff(width)
	self.hoveredTile = Vector2int16.new(0, 0)
	self._partCount = 0

	return self
end

function WorldMap.IsWalkable(self: WorldMap, x: number, z: number): boolean
	local terrainType = self.terrainMap[x][z]
	return terrainType ~= TerrainType.Ocean and terrainType ~= TerrainType.Shore and not self.featureMap[x][z]
end

function WorldMap._DrawTree(self: WorldMap, x: number, z: number)
	if typeof(x) ~= "number" or typeof(z) ~= "number" then
		error("Invalid arguments to _DrawTree")
	end
	local tree: Model = TreeModel:Clone()
	tree:PivotTo(CFrame.new(self.origin + Vector3.new(x, 1.5, z)))
	self.featureMap[x][z] = tree
	if typeof(z) == "string" then
		error("Found string" .. x .. " " .. z)
	end
	tree.Parent = workspace.Map.Features
end

function WorldMap._Draw(self: WorldMap, x: number, z: number)
	local terrainType = self.terrainMap[x][z]

	if terrainType == TerrainType.Ocean then
		self.tileMap[x][z] = workspace.Map.Ocean
		return
	end

	if self.terrainMap[x][z - 1] == terrainType then
		-- Extend previous part
		local previousPart = self.tileMap[x][z - 1]
		resize(previousPart, previousPart.Size.Z + 1)
		self.tileMap[x][z] = previousPart
		if terrainType == TerrainType.Forest then
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

		if terrainType == TerrainType.Grass then
			part.Color = Color3.fromRGB(107, 215, 116)
		elseif terrainType == TerrainType.Sand then
			part.Color = Color3.fromRGB(227, 216, 182)
		elseif terrainType == TerrainType.Shore then
			part.Color = Color3.fromRGB(133, 171, 243)
			part.Position -= Vector3.new(0, 1, 0)
		elseif terrainType == TerrainType.Forest then
			part.Color = Color3.fromRGB(107, 215, 116)
			self:_DrawTree(x, z)
		end

		self.tileMap[x][z] = part
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

function WorldMap.Generate(self: WorldMap)
	MapFolder:SetAttribute("Origin", self.origin)
	MapFolder:SetAttribute("Width", self.width)
	MapFolder:SetAttribute("Height", self.height)
	MapFolder:SetAttribute("Seed", self.seed)

	drawOcean(self.origin, self.width, self.height)

	for x = 1, self.width do
		self.tileMap[x] = table.create(self.height)
		self.featureMap[x] = table.create(self.height)
		self.terrainMap[x] = table.create(self.height)
		self.buildingMap[x] = table.create(self.height)
		for z = 1, self.height do
			local noise = math.noise(self.seed, x / 40, z / 40) - self.falloffMap[x][z]
			self.terrainMap[x][z] = if noise > TREE_THRESHOLD
				then TerrainType.Forest
				elseif noise > GRASS_THRESHOLD then TerrainType.Grass
				elseif noise > SAND_THRESHOLD then TerrainType.Sand
				elseif noise > SHORE_THRESHOLD then TerrainType.Shore
				else TerrainType.Ocean
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

-- TODO: Optimize
function WorldMap.FindPath(self: WorldMap, start: Vector2int16, goal: Vector2int16): { Vector2int16 }?
	-- ReplicaService occasionally decides to cast the Z value to a string. This is a band-aid fix.
	for x, row in self.featureMap do
		for z, feature in row do
			if typeof(z) == "string" then
				self.featureMap[x][tonumber(z)] = feature
			end
		end
	end

	if not self:IsWalkable(start.X, start.Y) or not self:IsWalkable(goal.X, goal.Y) then
		return nil
	end

	local openSet = { PathNode.new(start) }
	local closedSet = {}
	local path: { Vector2int16 } = {}
	goal = PathNode.new(goal)
	while #openSet ~= 0 do
		local currentNode: PathNode.PathNode = openSet[1]

		for _, node in openSet do
			if node.f <= currentNode.f and node.h < currentNode.h then
				currentNode = node
			end
		end

		table.remove(openSet, table.find(openSet, currentNode))
		table.insert(closedSet, currentNode)

		if currentNode == goal then
			while currentNode do
				table.insert(path, currentNode.Position)
				currentNode = currentNode.Parent
			end
			return reverse(path)
		end

		for _, neighbor in currentNode:GetNeighbors() do
			if table.find(closedSet, neighbor) or not self:IsWalkable(neighbor.Position.X, neighbor.Position.Y) then
				continue
			end
			local costToNeighbor = currentNode.g + currentNode:EstimateCost(neighbor)
			if costToNeighbor < neighbor.g or not table.find(openSet, neighbor) then
				neighbor.g = costToNeighbor
				neighbor.h = neighbor:EstimateCost(goal)
				neighbor.Parent = currentNode

				if not table.find(openSet, neighbor) then
					table.insert(openSet, neighbor)
				end
			end
		end
	end
	return
end

export type WorldMap = typeof(WorldMap.new(Vector3.zero, 0, 0))

return WorldMap
