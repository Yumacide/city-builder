local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Map = workspace:WaitForChild("Map")

local Maid = require(ReplicatedStorage.Common.Libraries:WaitForChild("Maid"))
local Signal = require(ReplicatedStorage.Packages:WaitForChild("Signal"))
local Spring = require(ReplicatedStorage.Common.Libraries:WaitForChild("Spring"))

local Building = {}
Building.__index = Building

Building.BuildingData = require(script.BuildingData)

function Building.new(name: string)
	local self = setmetatable({}, Building)

	self.Name = name
	self.Size = Building.BuildingData[name].Size
	self.ResourcesNeeded = table.clone(Building.BuildingData[name].Resources)
	self.ResourcesStored = {}
	self.IsSelected = false
	self.IsPlaced = false
	self.IsCompleted = false
	self.Data = {}
	self.GridPosition = Vector2int16.new(0, 0)
	self.Model = ReplicatedStorage.Assets.Buildings[name]:Clone() :: Model
	self.Maid = Maid.new()
	self.Placed = Signal.new()
	self.Completed = Signal.new()
	self.Destroying = Signal.new()
	self.PositionSpring = Spring.new(Vector3.zero)
	self.AngleSpring = Spring.new(0)
	self.Maid:GiveTask(self.Model)

	for _, part: BasePart in self.Model:GetChildren() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Building"
		end
	end

	self.Data.PreviousGoalPivot = self.Model:GetPivot()
	self.PositionSpring.Speed = 10
	self.AngleSpring.Speed = 10
	self.Data.AngleGoal = 0

	if not self.Model:FindFirstChild("BoundingBox") then
		local boundingBox = Instance.new("Part")
		boundingBox.Anchored = true
		boundingBox.Transparency = 1
		boundingBox.TopSurface = Enum.SurfaceType.Smooth
		boundingBox.BottomSurface = Enum.SurfaceType.Smooth
		boundingBox.Size = self.Size
		boundingBox.CFrame = self.Model:GetPivot()
		boundingBox.Name = "BoundingBox"
		boundingBox.Parent = self.Model
	end

	self.Model.Parent = Map.Buildings

	return self
end

function Building.Complete(self: Building)
	self.IsCompleted = true
	for _, part in self.Model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "BoundingBox" then
			part.Transparency = 0
		end
	end
	self.Completed:Fire()
end

function Building.Destroy(self: Building)
	if self.IsSelected and not self.IsPlaced then
		ContextActionService:UnbindAction("RotateBuilding")
		ContextActionService:UnbindAction("PlaceBuilding")
		--ContextActionService:UnbindAction("CancelBuilding")
		RunService:UnbindFromRenderStep("MoveBuilding")
		RunService:UnbindFromRenderStep("UpdateBuildingPivot")
	end
	self.Destroying:Fire()
	self.Maid:Destroy()
end

export type Building = typeof(Building.new(""))

return Building
