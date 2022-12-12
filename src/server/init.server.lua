local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- TODO: make a separate noise map for trees
-- TODO: make island object that contains all the tiles
type Map2D<T> = { { T } }

local TREE_THRESHOLD, GRASS_THRESHOLD, SAND_THRESHOLD, SHORE_THRESHOLD = 0.25, 0, -0.1, -0.2

local TreeModel = ReplicatedStorage.Assets.TreeModel

local partCount = 0

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

local function drawTree(part: Part, groundCFrame: CFrame)
	local tree: Model = TreeModel:Clone()
	tree:PivotTo(groundCFrame + Vector3.new(0, 1, 0))
	tree.Parent = part
end

local function draw(origin: Vector3, x: number, z: number, noiseMap: Map2D<number>, partMap: Map2D<Part>)
	local terrainIndex = noiseMap[x][z]

	if noiseMap[x][z - 1] == terrainIndex then
		-- Extend previous part
		local previousPart = partMap[x][z - 1]
		resize(previousPart, previousPart.Size.Z + 1)
		partMap[x][z] = previousPart
		if terrainIndex == 4 then
			drawTree(previousPart, CFrame.new(origin + Vector3.new(x, 0, z)))
		end
	else
		local part = Instance.new("Part")
		part.Size = Vector3.one
		part.Anchored = true
		part.Position = origin + Vector3.new(x, 0, z)
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
			drawTree(part, part.CFrame)
		elseif terrainIndex == 5 then
			part.Color = Color3.fromRGB(87, 132, 215)
			part.Position -= Vector3.new(0, 1, 0)
		end

		partMap[x][z] = part
		partCount += 1
	end
end

local function generateMap(origin: Vector3, width: number, height: number)
	local seed = Random.new():NextNumber(1, 100000)
	local falloff = generateFalloff(width)
	local map = table.create(width)
	local partMap = table.create(width)

	for x = 1, width do
		map[x] = table.create(height)
		partMap[x] = table.create(height)
		for z = 1, height do
			local noise = math.noise(seed, x / 40, z / 40) - falloff[x][z]
			map[x][z] = if noise > TREE_THRESHOLD
				then 4
				elseif noise > GRASS_THRESHOLD then 1
				elseif noise > SAND_THRESHOLD then 2
				elseif noise > SHORE_THRESHOLD then 3
				else 5
			draw(origin, x, z, map, partMap)
		end
		if x % 20 == 0 then
			task.wait()
		end
	end

	for x = 1, width do
		for z = 1, height do
			partMap[x][z].Parent = workspace.Map
		end
		if x % 20 == 0 then
			task.wait()
		end
	end
end

generateMap(Vector3.new(0, 1, 0), 250, 250)
warn("Part count: " .. partCount)
warn(string.format("Percentage of total tiles: %.3f%%", partCount / (500 * 500) * 100))
