--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Array2D = require(script.Parent.Array2D)
local PathNode = require(script.Parent.PathNode)
local Building = require(script.Parent.Building)

type Array2D<T> = Array2D.Array2D<T>

local MapFolder = workspace.Map

local TILES_DRAWN_PER_FRAME = 5000
local TREE_THRESHOLD, GRASS_THRESHOLD, SAND_THRESHOLD, SHORE_THRESHOLD = 0.25, 0, -0.1, -0.2

local TerrainType = {
	Forest = 1,
	Grass = 2,
	Sand = 3,
	Shore = 4,
	Ocean = 5,
}

local TreeModel = ReplicatedStorage.Assets.Tree

local WorldMap = {}
WorldMap.__index = WorldMap

-- Evaluate the falloff from a given value
local function evaluate(value: number)
	local a = 3
	local b = 2.2
	return value ^ a / (value ^ a + (b - b * value) ^ a)
end

local function generateFalloff(size: number): Array2D<number>
	local map = Array2D.new(size, size)
	for n = 1, size ^ 2 do
		local i, j = map:To2D(n)
		local x = i * 2 / size - 1
		local z = j * 2 / size - 1
		map.Array[n] = evaluate(math.max(math.abs(x), math.abs(z)))
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

local function resizeModel(model: Model, multiplier: Vector3)
	local primaryPart = model.PrimaryPart :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local relativePosition = part.Position - primaryPart.Position
			local rescaledPosition = relativePosition * multiplier
			part.Position = rescaledPosition + primaryPart.Position
			part.Size *= multiplier
		end
	end
end

function WorldMap.new(origin: Vector3, width: number, height: number)
	local self = setmetatable({}, WorldMap)

	self.origin = origin
	self.width = width
	self.height = height
	self.seed = Random.new():NextNumber(1, 100000)
	self.tileMap = Array2D.new(width, height) :: Array2D<Part>
	self.terrainMap = Array2D.new(width, height) :: Array2D<number>
	self.featureMap = Array2D.new(width, height) :: Array2D<Model>
	self.buildingMap = Array2D.new(width, height) :: Array2D<Building.Building>
	self.falloffMap = generateFalloff(width) :: Array2D<number>
	self.hoveredTile = Vector2int16.new(0, 0)
	self._partCount = 0

	return self
end

function WorldMap.IsWalkable(self: WorldMap, x: number, z: number): boolean
	local terrainType = self.terrainMap:Get(x, z)
	return terrainType ~= TerrainType.Ocean and terrainType ~= TerrainType.Shore
end

function WorldMap.CanBuild(self: WorldMap, building: Building.Building)
	return not (
		self.featureMap:Get(building.GridPosition.X, building.GridPosition.Y)
		or self.buildingMap:Get(building.GridPosition.X, building.GridPosition.Y)
	)
end

function WorldMap._DrawTree(self: WorldMap, n: number)
	local x, z = self.terrainMap:To2D(n)
	local tree: Model = TreeModel:Clone()
	resizeModel(tree, Vector3.one * (math.random() * 0.3 + 0.7))
	tree:PivotTo(
		CFrame.new(
			self.origin
				+ Vector3.new(
					x + math.random() * 0.5 - 0.25,
					0.5 + (tree.PrimaryPart :: BasePart).Size.Y / 2,
					z + math.random() * 0.5 - 0.25
				)
		) * CFrame.Angles(0, math.random() * math.pi, 0)
	)
	self.featureMap.Array[n] = tree
	tree.Parent = workspace.Map.Features
end

function WorldMap._Draw(self: WorldMap, n: number)
	local x, z = self.terrainMap:To2D(n)
	local terrainType = self.terrainMap.Array[n]

	if terrainType == TerrainType.Ocean then
		self.tileMap.Array[n] = workspace.Map.Ocean
		return
	end

	if self.terrainMap:Get(x, z - 1) == terrainType then
		-- Extend previous part
		local previousPart = self.tileMap:Get(x, z - 1)
		resize(previousPart, previousPart.Size.Z + 1)
		self.tileMap.Array[n] = previousPart
		if terrainType == TerrainType.Forest then
			self:_DrawTree(n)
		end
	else
		local part = Instance.new("Part")
		part.Size = Vector3.one
		part.Anchored = true
		part.CastShadow = false
		part.Position = self:WorldPosFromGridPos(Vector2int16.new(x, z))
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
			self:_DrawTree(n)
		end

		self.tileMap.Array[n] = part
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

function WorldMap.Generate(self: WorldMap, shouldDraw: boolean)
	drawOcean(self.origin, self.width, self.height)

	for n = 1, self.width * self.height do
		local x, z = self.terrainMap:To2D(n)
		local noise = math.noise(self.seed, x / 40, z / 40) - self.falloffMap.Array[n]
		self.terrainMap.Array[n] = if noise > TREE_THRESHOLD
			then TerrainType.Forest
			elseif noise > GRASS_THRESHOLD then TerrainType.Grass
			elseif noise > SAND_THRESHOLD then TerrainType.Sand
			elseif noise > SHORE_THRESHOLD then TerrainType.Shore
			else TerrainType.Ocean
		if shouldDraw then
			self:_Draw(n)
		end
	end

	if shouldDraw then
		for n = 1, self.width * self.height do
			self.tileMap.Array[n].Parent = workspace.Map.Tiles
			if n % TILES_DRAWN_PER_FRAME == 0 then
				task.wait()
			end
		end
	end

	table.clear(self.falloffMap)
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

-- TODO: Make it so that a person doesn't have to move tile-by-tile
function WorldMap.FindPath(self: WorldMap, start: Vector2int16, goal: Vector2int16): { Vector2int16 }?
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

function WorldMap.UpdateCapacity(self: WorldMap)
	local capacity = 0
	for _, building in self.buildingMap.Array do
		if building.Name == "Hovel" then
			capacity += 5
		end
	end
	MapFolder:SetAttribute("Capacity", capacity)
	MapFolder:SetAttribute("Population", capacity) -- Until I implement visits.
end

export type WorldMap = typeof(WorldMap.new(Vector3.zero, 0, 0))

return WorldMap
