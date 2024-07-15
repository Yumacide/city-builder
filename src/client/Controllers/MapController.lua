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
	setmetatable(replica.Data.Map, WorldMap)
	RunService:BindToRenderStep("GetHoveredTile", 1, function()
		local ray = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { workspace.Map.Tiles }
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)
		if not raycastResult then
			return
		end
		local hoveredTile = replica.Data.Map:GridPosFromWorldPos(replica.Data.Map:SnapToGrid(raycastResult.Position))
		local building = replica.Data.Map.buildingMap[hoveredTile.X][hoveredTile.Y]
		replica.Data.Map.hoveredTile = hoveredTile
		HoveredTileBox.Text =
			`Hovered Tile:  {replica.Data.Map.hoveredTile}\nBuilding: {building and building.Name or "None"}`
		HoveredTileBox.Position = UDim2.fromOffset(Mouse.X, Mouse.Y)
	end)
end)

ReplicaController.RequestData()

return MapController
