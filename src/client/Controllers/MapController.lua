local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ReplicaController = require(ReplicatedStorage.Common.Libraries.ReplicaController)
local WorldMap = require(ReplicatedStorage.Common.WorldMap)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local MapController = {}

ReplicaController.ReplicaOfClassCreated("MapReplica", function(replica)
	local HoveredTileBox: TextBox = Player.PlayerGui:WaitForChild("ScreenGui"):WaitForChild("HoveredTile")
	MapController.MapReplica = replica

	local map = replica.Data.Map
	setmetatable(map, WorldMap)
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
		HoveredTileBox.Text =
			`Hovered Tile:  {map.hoveredTile}\n{building and building.Name or feature and feature.Name or "None"}`
		HoveredTileBox.Position = UDim2.new(0.015, Mouse.X, -0.01, Mouse.Y)
	end)
end)

ReplicaController.RequestData()

return MapController
