local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Map = workspace:WaitForChild("Map")

local Maid = require(ReplicatedStorage.Common:WaitForChild("Maid"))

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
	self.Selected = false
	self.Placed = false
	self.Model = ReplicatedStorage.Assets.Buildings[name]:Clone() :: Model
	self.Maid = Maid.new()

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

function Building.Select(self: Building)
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
		print(self.Model.PrimaryPart.Position)
	end)
end

function Building.Destroy(self: Building)
	self.Maid:Destroy()
end

export type Building = typeof(Building.new(""))

return Building
