local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Map = workspace:WaitForChild("Map")

local Maid = require(ReplicatedStorage.Common.Libraries:WaitForChild("Maid"))
local Signal = require(ReplicatedStorage.Packages:WaitForChild("Signal"))
local WorldMap = require(script.Parent.WorldMap)
local Spring = require(ReplicatedStorage.Common.Libraries:WaitForChild("Spring"))

local MapController
if RunService:IsClient() then
	MapController = require(Players.LocalPlayer.PlayerScripts:WaitForChild("Controllers"):WaitForChild("MapController"))
end

local Building = {}
Building.__index = Building

local BuildingData = {
	Road = {
		Size = Vector3.new(1, 1, 1),
		Resources = {
			Wood = 1,
		},
	},
	Keep = {
		Size = Vector3.new(2, 2, 2),
		Resources = {
			Wood = 1,
		},
	},
}

function Building.new(name: string)
	local self = setmetatable({}, Building)

	self.Name = name
	self.Size = BuildingData[name].Size
	self.ResourcesNeeded = table.clone(BuildingData[name].Resources)
	self.ResourcesStored = {}
	self.IsSelected = false
	self.IsPlaced = false
	self.IsCompleted = false
	self.Data = {}
	self.Model = ReplicatedStorage.Assets.Buildings[name]:Clone() :: Model
	self.Maid = Maid.new()
	self.Placed = Signal.new()
	self.Destroying = Signal.new()
	self.PositionSpring = Spring.new(Vector3.zero)
	self.AngleSpring = Spring.new(0)
	self.Maid:GiveTask(self.Model)

	self.Data.PreviousGoalPivot = self.Model:GetPivot()
	self.PositionSpring.Speed = 10
	self.AngleSpring.Speed = 10
	self.Data.AngleGoal = 0

	local boundingBox = Instance.new("Part")
	boundingBox.Anchored = true
	boundingBox.Transparency = 1
	boundingBox.TopSurface = Enum.SurfaceType.Smooth
	boundingBox.BottomSurface = Enum.SurfaceType.Smooth
	boundingBox.Size = self.Size
	boundingBox.CFrame = self.Model:GetPivot()
	boundingBox.Name = "BoundingBox"
	boundingBox.Parent = self.Model

	self.Model.Parent = Map.Buildings

	return self
end

function Building.Plan(self: Building, bindControls: boolean)
	local map: WorldMap.WorldMap = setmetatable(MapController.MapReplica.Data.Map, WorldMap)
	self.IsSelected = true
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.LineThickness = 0.01
	selectionBox.Transparency = 0.5
	selectionBox.Adornee = self.Model.BoundingBox
	selectionBox.Parent = self.Model
	for _, part: Part in self.Model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "BoundingBox" then
			part.Transparency = 0.25
		end
	end
	self.Model.Parent = workspace

	if not bindControls then
		return
	end

	ContextActionService:BindAction("RotateBuilding", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		self.Data.AngleGoal += math.pi / 2
	end, false, Enum.KeyCode.R)

	ContextActionService:BindAction("PlaceBuilding", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		self:Place(true)
	end, false, Enum.UserInputType.MouseButton1)

	ContextActionService:BindAction("CancelBuilding", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.End then
			return
		end
		print("canceling")
		self:Destroy()
	end, false, Enum.KeyCode.F)

	RunService:BindToRenderStep("MoveBuilding", 1, function()
		-- TODO: raycast to filter non-tiles instead
		local target = Mouse.Target
		if target.Parent ~= workspace.Map.Tiles then
			return
		end
		self.Data.GoalPivot = CFrame.new(
			map:WorldPosFromGridPos(map:GetHoveredTile())
				+ Vector3.new(
					if self.Size.X % 2 == 1 then 0 else 0.5,
					0.5 * (1 + self.Size.Y),
					if self.Size.Z % 2 == 1 then 0 else 0.5
				)
		) * (self.Model:GetPivot() - self.Model:GetPivot().Position)
	end)

	-- this sucks, use this video to do it properly: https://www.youtube.com/watch?v=Db3LooLQM1Q&t=590s
	RunService:BindToRenderStep("UpdateBuildingPivot", 2, function(deltaTime)
		local positionGoal = self.Data.GoalPivot.Position
		local angleGoal = self.Data.AngleGoal

		local previousAngleGoal = self.AngleSpring.Target -- use later

		local delta = angleGoal - previousAngleGoal
		if delta > math.pi then
			angleGoal += math.pi * 2
		elseif delta < -math.pi then
			angleGoal -= math.pi * 2
		end
		self.Data.AngleGoal = angleGoal

		self.PositionSpring.Target = positionGoal
		self.AngleSpring.Target = angleGoal

		self.PositionSpring:TimeSkip(deltaTime)
		self.AngleSpring:TimeSkip(deltaTime)
		self.Model:PivotTo(CFrame.new(self.PositionSpring.Position) * CFrame.Angles(0, self.AngleSpring.Position, 0))
	end)
end

function Building.Place(self: Building, instantBuild: boolean)
	self.Model.Parent = Map.Buildings
	self.IsPlaced = true

	ContextActionService:UnbindAction("RotateBuilding")
	ContextActionService:UnbindAction("PlaceBuilding")
	RunService:UnbindFromRenderStep("MoveBuilding")
	-- TODO: wait until its done moving
	RunService:UnbindFromRenderStep("UpdateBuildingPivot")
	if self.Name == "Road" then
		self:PlaceRoad(instantBuild)
		return
	end
	ContextActionService:UnbindAction("CancelBuilding")
	self.Model.SelectionBox:Destroy()

	self.Placed:Fire()
	if instantBuild then
		self:Complete()
	end
end

-- TODO: Use a part pool
function Building.PlaceRoad(self: Building, instantBuild: boolean)
	local map: WorldMap.WorldMap = setmetatable(MapController.MapReplica.Data.Map, WorldMap)
	local start = map:GridPosFromWorldPos(self.Model.PrimaryPart.Position)
	local goal: Vector2int16
	self.Data.Roads = {}
	RunService:BindToRenderStep("ExtendRoad", 1, function()
		local currentGoal = map:GetHoveredTile()
		if goal == currentGoal then
			return
		end
		goal = currentGoal

		for _, road: Building in self.Data.Roads do
			road:Destroy()
		end
		table.clear(self.Data.Roads)

		local path = map:FindPath(start, goal)
		if not path then
			return
		end
		table.remove(path, 1)
		local previousPoint
		for _, point in path do
			local road = Building.new("Road")
			road:Plan(false)
			road.Model:PivotTo(CFrame.new(map:WorldPosFromGridPos(point)) + Vector3.new(0, 1, 0))
			table.insert(self.Data.Roads, road)

			if previousPoint then
				local delta = point - previousPoint
				if delta.X == 0 then
					road.Model:PivotTo(road.Model:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
				end
			end
			previousPoint = point
		end
	end)
	ContextActionService:BindAction("PlaceRoad", function(_, inputState)
		if inputState ~= Enum.UserInputState.End then
			print("not end")
			return
		end
		print("end")

		ContextActionService:UnbindAction("CancelBuilding")
		ContextActionService:UnbindAction("PlaceRoad")
		RunService:UnbindFromRenderStep("ExtendRoad")
		-- TODO: wait until its done moving
		RunService:UnbindFromRenderStep("UpdateBuildingPivot")

		self.Model.SelectionBox:Destroy()
		self.Placed:Fire()
		if instantBuild then
			self:Complete()
		end

		for _, road: Building in self.Data.Roads do
			road.Model.SelectionBox:Destroy()

			road.Placed:Fire()
			if instantBuild then
				road:Complete()
			end
		end
	end, false, Enum.UserInputType.MouseButton1)
end

function Building.Complete(self: Building)
	self.IsCompleted = true
	for _, part in self.Model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "BoundingBox" then
			part.Transparency = 0
		end
	end
end

function Building.Destroy(self: Building)
	if self.IsSelected and not self.IsPlaced then
		ContextActionService:UnbindAction("RotateBuilding")
		ContextActionService:UnbindAction("PlaceBuilding")
		--ContextActionService:UnbindAction("CancelBuilding")
		RunService:UnbindFromRenderStep("MoveBuilding")
		-- TODO: wait until its done moving
		RunService:UnbindFromRenderStep("UpdateBuildingPivot")
	end
	self.Destroying:Fire()
	if self.Data.Roads then
		print("unbinding extend")
		RunService:UnbindFromRenderStep("ExtendRoad")
		for _, road in self.Data.Roads do
			road:Destroy()
		end
	end
	self.Maid:Destroy()
end

export type Building = typeof(Building.new(""))

return Building
