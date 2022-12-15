-- This is getting somewhat messy -- need to refactor later.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Map = workspace:WaitForChild("Map")

local BuildingPlaced = ReplicatedStorage.Remotes:WaitForChild("BuildingPlaced")

local Maid = require(ReplicatedStorage.Common.Libraries:WaitForChild("Maid"))
local Signal = require(ReplicatedStorage.Packages:WaitForChild("Signal"))
local WorldMap = require(script.Parent.WorldMap)
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
}

-- fix when origin is not 0,0, move to WorldMap
local function snapToGrid(origin: Vector3, pos: Vector3, width: number, height: number)
	return Vector3.new(
		math.round(math.clamp(pos.X, origin.X, origin.X + width)),
		pos.Y,
		math.round(math.clamp(pos.Z, origin.Z, origin.Z + height))
	)
end

local function Vector2int16Magnitude(vector: Vector2int16)
	return math.sqrt(vector.X ^ 2 + vector.Y ^ 2)
end

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
	self.Maid:GiveTask(self.Model)

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
		self.Model.PrimaryPart.CFrame *= CFrame.Angles(0, math.rad(90), 0)
	end, false, Enum.KeyCode.R)

	ContextActionService:BindAction("PlaceBuilding", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		self:Place(true)
	end, false, Enum.UserInputType.MouseButton1)

	ContextActionService:BindAction("CancelBuilding", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		self:Destroy()
	end, false, Enum.UserInputType.MouseButton2)

	RunService:BindToRenderStep("MoveBuilding", 1, function()
		-- TODO: raycast to filter non-tiles instead
		local target = Mouse.Target
		if target.Parent ~= workspace.Map.Tiles then
			return
		end
		self.Model:PivotTo(
			CFrame.new(
				snapToGrid(
					Map:GetAttribute("Origin"),
					Mouse.Hit.Position,
					Map:GetAttribute("Width"),
					Map:GetAttribute("Height")
				) + Vector3.new(0, 0.01, 0)
			) * (self.Model:GetPivot() - self.Model:GetPivot().Position)
		)
	end)
end

function Building.Place(self: Building, instantBuild: boolean)
	self.Model.Parent = Map.Buildings
	self.IsPlaced = true

	ContextActionService:UnbindAction("RotateBuilding")
	ContextActionService:UnbindAction("PlaceBuilding")
	RunService:UnbindFromRenderStep("MoveBuilding")
	if self.Name == "Road" then
		self:PlaceRoad(instantBuild)
		return
	end
	ContextActionService:UnbindAction("CancelBuilding")
	self.Model.SelectionBox:Destroy()

	if instantBuild then
		self:Complete()
	end
	self.Placed:Fire()
end

-- TODO: use a part pool
function Building.PlaceRoad(self: Building, instantBuild: boolean)
	local map: WorldMap.WorldMap = setmetatable(MapController.MapReplica.Data.Map, WorldMap)
	local start = map:GridPosFromWorldPos(self.Model.PrimaryPart.Position)
	local goal: Vector2int16
	self.Data.Roads = {}
	RunService:BindToRenderStep("ExtendRoad", 1, function()
		local startTime = os.clock()
		local target = Mouse.Target
		if target.Parent ~= workspace.Map.Tiles then
			return
		end
		local currentGoal = map:GridPosFromWorldPos(snapToGrid(map.origin, Mouse.Hit.Position, map.width, map.height))
		if goal == currentGoal then
			return
		end
		goal = currentGoal

		for _, road in self.Data.Roads do
			road:Destroy()
		end
		table.clear(self.Data.Roads)

		local path = map:FindPath(start, goal, false)
		for _, waypoint in path do
			local direction
			local delta = waypoint - start
			if waypoint.X == start.X then
				direction = delta / math.abs(delta.Y)
			else
				direction = delta / math.abs(delta.X)
			end

			for i = 0, Vector2int16Magnitude(delta) do
				local road = Building.new("Road")
				road:Plan(false)
				road.Model:PivotTo(CFrame.new(map:WorldPosFromGridPos(start + direction * i)) + Vector3.new(0, 0.01, 0))
				table.insert(self.Data.Roads, road)
			end
			start = waypoint
		end

		if os.clock() - startTime > 0.1 then
			warn("Road placement took too long")
			RunService:UnbindFromRenderStep("ExtendRoad")
		end
	end)
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
		ContextActionService:UnbindAction("CancelBuilding")
		RunService:UnbindFromRenderStep("MoveBuilding")
	end
	self.Destroying:Fire()
	if self.Data.Roads then
		for _, road in self.Data.Roads do
			road:Destroy()
		end
	end
	self.Maid:Destroy()
end

export type Building = typeof(Building.new(""))

return Building
