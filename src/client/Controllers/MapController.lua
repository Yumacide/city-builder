local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ReplicaController = require(ReplicatedStorage.Common.Libraries.ReplicaController)
local WorldMap = require(ReplicatedStorage.Common.WorldMap)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local MapFolder = workspace.Map
local ScreenGui = Player.PlayerGui:WaitForChild("ScreenGui")
local HoveredTileLabel: TextLabel = ScreenGui:WaitForChild("HoveredTile")
local PopulationLabel: TextLabel = ScreenGui:WaitForChild("Population")

local MapController = { MapCreated = Signal.new() }

function MapController.GetMap(self)
	return self.MapReplica and self.MapReplica.Data.Map or self.MapCreated:Wait()
end

ReplicaController.ReplicaOfClassCreated("MapReplica", function(replica)
	MapController.MapReplica = replica

	local map = replica.Data.Map
	setmetatable(map, WorldMap)
	MapController.MapCreated:Fire(map)

	-- ReplicaService occasionally decides to cast the Z value to a string.
	-- I figured out a fix for this 2 years ago, but I forgot what it was, so this is a band-aid fix.
	for x, row in map.featureMap do
		for z, feature in row do
			if typeof(z) == "string" then
				map.featureMap[x][z] = nil
				map.featureMap[x][tonumber(z)] = feature
			end
		end
	end

	RunService:BindToRenderStep("GetHoveredTile", 1, function()
		local ray = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { workspace.Map.Tiles }
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)
		if not raycastResult then
			return
		end
		local hoveredTile = map:GridPosFromWorldPos(map:SnapToGrid(raycastResult.Position))
		local building = map.buildingMap[hoveredTile.X][hoveredTile.Y]
		local feature = map.featureMap[hoveredTile.X][hoveredTile.Y]
		map.hoveredTile = hoveredTile
		HoveredTileLabel.Text =
			`Hovered Tile:  {map.hoveredTile}\n{building and building.Name or feature and feature.Name or "None"}`
		HoveredTileLabel.Position = UDim2.new(0.015, Mouse.X, -0.01, Mouse.Y)
	end)
end)

local function updatePopulationLabel()
	PopulationLabel.Text = `Population:  {MapFolder:GetAttribute("Population")}/{MapFolder:GetAttribute("Capacity")}`
end

MapFolder:GetAttributeChangedSignal("Capacity"):Connect(updatePopulationLabel)
MapFolder:GetAttributeChangedSignal("Population"):Connect(updatePopulationLabel)

ReplicaController.RequestData()

return MapController
