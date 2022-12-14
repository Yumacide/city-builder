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

-- fix when origin is not 0,0
local function snapToGrid(origin: Vector3, pos: Vector3, width: number, height: number)
	return Vector3.new(
		math.round(math.clamp(pos.X, origin.X, origin.X + width)),
		pos.Y,
		math.round(math.clamp(pos.Z, origin.Z, origin.Z + height))
	)
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
	self.Model = ReplicatedStorage.Assets.Buildings[name]:Clone() :: Model
	self.Maid = Maid.new()
	self.Placed = Signal.new()
	self.Destroying = Signal.new()
	self.Maid:GiveTask(self.Model)

	local boundingBox = Instance.new("Part")
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

function Building.Plan(self: Building)
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
				) + Vector3.new(0, 0.1, 0)
			)
		)
	end)
end

function Building.Place(self: Building, instantBuild: boolean)
	self.Model.Parent = Map.Buildings
	self.IsPlaced = true

	ContextActionService:UnbindAction("RotateBuilding")
	ContextActionService:UnbindAction("PlaceBuilding")
	ContextActionService:UnbindAction("CancelBuilding")
	RunService:UnbindFromRenderStep("MoveBuilding")
	self.Model.SelectionBox:Destroy()

	if instantBuild then
		self:Complete()
	end
	self.Placed:Fire()
end

function Building.Complete(self: Building)
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
	self.Maid:Destroy()
end

export type Building = typeof(Building.new(""))

return Building
