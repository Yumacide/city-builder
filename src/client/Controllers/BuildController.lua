local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldMap = require(ReplicatedStorage.Common.WorldMap)
local Building = require(ReplicatedStorage.Common.Building)
local MapController = require(script.Parent.MapController)
local Map = workspace:WaitForChild("Map")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

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
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.LineThickness = 0.01
	selectionBox.Transparency = 0.5
	selectionBox.Adornee = building.Model.BoundingBox
	selectionBox.Parent = building.Model
	for _, part: Part in building.Model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "BoundingBox" then
			part.Transparency = 0.25
		end
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
		print("canceling")
		building:Destroy()
	end, false, Enum.KeyCode.F)

	RunService:BindToRenderStep("MoveBuilding", 1, function()
		-- TODO: raycast to filter non-tiles instead
		local target = Mouse.Target
		if target.Parent ~= workspace.Map.Tiles then
			return
		end
		building.GridPosition = map.hoveredTile
		building.Data.GoalPivot = CFrame.new(
			map:WorldPosFromGridPos(map.hoveredTile)
				+ Vector3.new(
					if building.Size.X % 2 == 1 then 0 else 0.5,
					0.5 * (1 + building.Size.Y),
					if building.Size.Z % 2 == 1 then 0 else 0.5
				)
		) * (building.Model:GetPivot() - building.Model:GetPivot().Position)
	end)

	-- this sucks, use this video to do it properly: https://www.youtube.com/watch?v=Db3LooLQM1Q&t=590s
	RunService:BindToRenderStep("UpdateBuildingPivot", 2, function(deltaTime)
		local positionGoal = building.Data.GoalPivot.Position
		local angleGoal = building.Data.AngleGoal

		local previousAngleGoal = building.AngleSpring.Target -- use later

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
	building.Model.Parent = Map.Buildings
	building.IsPlaced = true

	local map: WorldMap.WorldMap = MapController.MapReplica.Data.Map
	map.buildingMap[building.GridPosition.X][building.GridPosition.Y] = building

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
	building.Model.SelectionBox:Destroy()

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
	building.Model.SelectionBox.Color = BrickColor.Black()

	if not self.PlannedRoadsMap[start.X] then
		self.PlannedRoadsMap[start.X] = {}
	end
	self.PlannedRoadsMap[start.X][start.Y] = building

	RunService:BindToRenderStep("ExtendRoad", 1, function()
		local currentGoal = map.hoveredTile
		if goal == currentGoal then
			return
		end
		goal = currentGoal

		for _, road: Building.Building in self.PlannedRoads do
			road:Destroy()
		end
		table.clear(self.PlannedRoads)
		table.clear(self.PlannedRoadsMap)

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
			-- local nextPoint = path[i + 1]
			local road = Building.new("Road")
			road.GridPosition = point
			self:Plan(road, false)
			if point == goal then
				road.Model.SelectionBox.Color = BrickColor.Red()
			end
			table.insert(self.PlannedRoads, road)

			if not self.PlannedRoadsMap[point.X] then
				self.PlannedRoadsMap[point.X] = {}
			end
			self.PlannedRoadsMap[point.X][point.Y] = road

			local position = map:WorldPosFromGridPos(point) + Vector3.yAxis
			road.Model:PivotTo(CFrame.new(position))
		end
		self:RedrawRoads(building)
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

		building.Model.SelectionBox:Destroy()
		building.Placed:Fire()
		if instantBuild then
			building:Complete()
		end

		for _, road: Building.Building in self.PlannedRoads do
			road.Model.SelectionBox:Destroy()

			road.Placed:Fire()
			if instantBuild then
				road:Complete()
			end
		end
		table.clear(self.PlannedRoads)
	end, false, Enum.UserInputType.MouseButton1)
end

function BuildController.RedrawRoads(self: BuildController, road: Building.Building)
	local closedSet = {}
	local openSet = { road }
	local map = MapController.MapReplica.Data.Map :: WorldMap.WorldMap
	while #openSet ~= 0 do
		local currentRoad = openSet[1]
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
			if not table.find(closedSet, neighborRoad) then
				table.insert(openSet, neighborRoad)
			end

			local roadConnection = RoadConnection:Clone()
			roadConnection:PivotTo(
				CFrame.lookAlong(
					map:WorldPosFromGridPos(currentRoad.GridPosition)
						+ Vector3.new(direction.X * 0.425, 1, direction.Y * 0.425),
					Vector3.new(direction.X, 0, direction.Y)
				)
			)
			roadConnection.Transparency = 0.25
			roadConnection.Parent = currentRoad.Model
		end

		table.insert(closedSet, currentRoad)
		table.remove(openSet, 1)
	end
end

return BuildController
