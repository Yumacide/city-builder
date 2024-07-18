local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldMap = require(ReplicatedStorage.Common.WorldMap)
local Building = require(ReplicatedStorage.Common.Building)
local MapController = require(script.Parent.MapController)
local Map = workspace:WaitForChild("Map")

local RoadConnection = ReplicatedStorage.Assets.Buildings:WaitForChild("RoadConnection")

local DIRECTIONS = {
	Vector2int16.new(1, 0),
	Vector2int16.new(-1, 0),
	Vector2int16.new(0, 1),
	Vector2int16.new(0, -1),
}

local BuildController = {
	PlannedRoads = {},
	PlannedRoadsMap = {},
}
export type BuildController = typeof(BuildController)

function BuildController.Plan(self: BuildController, building: Building.Building, bindControls: boolean)
	local map: WorldMap.WorldMap = MapController.MapReplica.Data.Map
	building.IsSelected = true

	local highlight = Instance.new("Highlight")
	highlight.Adornee = building.Model
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.9
	highlight.Enabled = true
	highlight.Parent = building.Model
	if not map:CanBuild(building) then
		highlight.OutlineColor = Color3.new(1, 0, 0)
	end
	building.Model.Parent = Map.Buildings

	if not bindControls then
		return
	end

	ContextActionService:BindAction("RotateBuilding", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		building.Data.AngleGoal += math.pi / 2
	end, false, Enum.KeyCode.R)

	ContextActionService:BindAction("PlaceBuilding", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		self:Place(building, true)
	end, false, Enum.UserInputType.MouseButton1)

	ContextActionService:BindAction("CancelBuilding", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.End then
			return
		end
		for _, road in self.PlannedRoads do
			road:Destroy()
		end
		table.clear(self.PlannedRoads)
		table.clear(self.PlannedRoadsMap)
		building:Destroy()
	end, false, Enum.KeyCode.F)

	RunService:BindToRenderStep("MoveBuilding", 1, function()
		if map.hoveredTile == building.GridPosition then
			return
		end
		building.GridPosition = map.hoveredTile
		if map:CanBuild(building) then
			highlight.OutlineColor = Color3.new(1, 1, 1)
		else
			highlight.OutlineColor = Color3.new(1, 0, 0)
		end

		building.Data.GoalPivot = CFrame.new(
			map:WorldPosFromGridPos(map.hoveredTile)
				+ Vector3.new(
					if building.Size.X % 2 == 1 then 0 else 0.5,
					0.5 * (1 + building.Size.Y),
					if building.Size.Z % 2 == 1 then 0 else 0.5
				)
		) * (building.Model:GetPivot() - building.Model:GetPivot().Position)
	end)

	RunService:BindToRenderStep("UpdateBuildingPivot", 2, function(deltaTime)
		local positionGoal = building.Data.GoalPivot.Position
		local angleGoal = building.Data.AngleGoal

		local previousAngleGoal = building.AngleSpring.Target

		local delta = angleGoal - previousAngleGoal
		if delta > math.pi then
			angleGoal += math.pi * 2
		elseif delta < -math.pi then
			angleGoal -= math.pi * 2
		end
		building.Data.AngleGoal = angleGoal

		building.PositionSpring.Target = positionGoal
		building.AngleSpring.Target = angleGoal

		building.PositionSpring:TimeSkip(deltaTime)
		building.AngleSpring:TimeSkip(deltaTime)
		building.Model:PivotTo(
			CFrame.new(building.PositionSpring.Position) * CFrame.Angles(0, building.AngleSpring.Position, 0)
		)
	end)
end

function BuildController.Place(self: BuildController, building: Building.Building, instantBuild: boolean)
	local map: WorldMap.WorldMap = MapController.MapReplica.Data.Map
	building.Model.Parent = Map.Buildings
	building.IsPlaced = true

	ContextActionService:UnbindAction("RotateBuilding")
	ContextActionService:UnbindAction("PlaceBuilding")
	RunService:UnbindFromRenderStep("MoveBuilding")
	-- TODO: wait until its done moving
	RunService:UnbindFromRenderStep("UpdateBuildingPivot")
	if building.Name == "Road" then
		self:PlaceRoad(building, instantBuild)
		return
	end
	ContextActionService:UnbindAction("CancelBuilding")

	if not map:CanBuild(building) then
		building.Model:Destroy()
		return
	end

	map.buildingMap[building.GridPosition.X][building.GridPosition.Y] = building
	building.Model.Highlight:Destroy()
	building.Placed:Fire()
	if instantBuild then
		building:Complete()
	end
end

-- TODO: Use a part pool
function BuildController.PlaceRoad(self: BuildController, building: Building.Building, instantBuild: boolean)
	local map: WorldMap.WorldMap = setmetatable(MapController.MapReplica.Data.Map, WorldMap)
	local start = building.GridPosition
	local goal: Vector2int16

	RunService:BindToRenderStep("ExtendRoad", 1, function()
		local currentGoal = map.hoveredTile
		if goal == currentGoal then
			return
		end
		goal = currentGoal

		for _, road: Building.Building in self.PlannedRoads do
			if road ~= building then
				road:Destroy()
			end
		end
		table.clear(self.PlannedRoads)
		table.clear(self.PlannedRoadsMap)

		table.insert(self.PlannedRoads, building)
		if not self.PlannedRoadsMap[start.X] then
			self.PlannedRoadsMap[start.X] = {}
		end
		self.PlannedRoadsMap[start.X][start.Y] = building

		local path = {}
		local offset = goal - start
		for i = if offset.X < 0 then -1 else 1, offset.X, if offset.X < 0 then -1 else 1 do
			table.insert(path, Vector2int16.new(start.X + i, start.Y))
		end
		for i = if offset.Y < 0 then -1 else 1, offset.Y, if offset.Y < 0 then -1 else 1 do
			table.insert(path, Vector2int16.new(goal.X, start.Y + i))
		end
		if path[1] == start then
			table.remove(path, 1)
		end

		for _, point in path do
			local road = Building.new("Road")
			road.GridPosition = point
			self:Plan(road, false)
			table.insert(self.PlannedRoads, road)
			road.Model.Parent = Map.Buildings.PlannedRoads

			if not self.PlannedRoadsMap[point.X] then
				self.PlannedRoadsMap[point.X] = {}
			end
			self.PlannedRoadsMap[point.X][point.Y] = road

			local position = map:WorldPosFromGridPos(point) + Vector3.yAxis
			road.Model:PivotTo(CFrame.new(position))
		end
		self:RedrawRoads()
	end)
	ContextActionService:BindAction("PlaceRoad", function(_, inputState)
		if inputState ~= Enum.UserInputState.End then
			return
		end
		ContextActionService:UnbindAction("CancelBuilding")
		ContextActionService:UnbindAction("PlaceRoad")
		RunService:UnbindFromRenderStep("ExtendRoad")
		-- TODO: wait until its done moving
		RunService:UnbindFromRenderStep("UpdateBuildingPivot")

		for _, road: Building.Building in self.PlannedRoads do
			if not map:CanBuild(road) then
				road.Model:Destroy()
				continue
			end

			map.buildingMap[road.GridPosition.X][road.GridPosition.Y] = road

			road.IsPlaced = true
			road.Model.Highlight:Destroy()
			road.Model.Parent = Map.Buildings
			road.Placed:Fire()
			if instantBuild then
				road:Complete()
			end
		end

		table.clear(self.PlannedRoads)
	end, false, Enum.UserInputType.MouseButton1)
end

function BuildController._RedrawRoad(self: BuildController, currentRoad: Building.Building)
	local map = MapController.MapReplica.Data.Map :: WorldMap.WorldMap

	for _, roadConnection in currentRoad.Model:GetChildren() do
		if roadConnection.Name ~= "RoadConnection" then
			continue
		end
		roadConnection:Destroy()
	end
	for _, direction in DIRECTIONS do
		local neighborPosition = currentRoad.GridPosition + direction
		local neighborRoad = map.buildingMap[neighborPosition.X][neighborPosition.Y]
			or self.PlannedRoadsMap[neighborPosition.X]
				and self.PlannedRoadsMap[neighborPosition.X][neighborPosition.Y]
		if not (neighborRoad and neighborRoad.Name == "Road") then
			continue
		end

		local roadConnection = RoadConnection:Clone()
		roadConnection:PivotTo(
			CFrame.lookAlong(
				map:WorldPosFromGridPos(currentRoad.GridPosition)
					+ Vector3.new(direction.X * 0.425, 1, direction.Y * 0.425),
				Vector3.new(direction.X, 0, direction.Y)
			)
		)
		roadConnection.Parent = currentRoad.Model
	end
end

function BuildController.RedrawRoads(self: BuildController)
	local map = MapController.MapReplica.Data.Map :: WorldMap.WorldMap
	for _, roads in map.buildingMap do
		for _, road in roads do
			self:_RedrawRoad(road)
		end
	end
	for _, road in self.PlannedRoads do
		self:_RedrawRoad(road)
	end
end

return BuildController
