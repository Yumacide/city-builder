local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ReplicaController = require(ReplicatedStorage.Common.Libraries.ReplicaController)
local Spring = require(ReplicatedStorage.Common.Libraries.Spring)
local WorldMap = require(ReplicatedStorage.Common.WorldMap)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local MapFolder = workspace.Map
local SelectionBox = ReplicatedStorage.Assets.SelectionBox
local ScreenGui = Player.PlayerGui:WaitForChild("ScreenGui")
local HoveredTileLabel: TextLabel = ScreenGui:WaitForChild("HoveredTile")
local PopulationLabel: TextLabel = ScreenGui:WaitForChild("Population")

local MapController = { MapCreated = Signal.new() }

function MapController.GetMap(self): WorldMap.WorldMap
	return self.ClientMap or self.MapCreated:Wait()
end

ReplicaController.ReplicaOfClassCreated("MapReplica", function(replica)
	MapController.MapReplica = replica

	local serverMap = replica.Data.Map
	setmetatable(serverMap, WorldMap)

	local map = WorldMap.new(serverMap.origin, serverMap.width, serverMap.height)
	map.seed = serverMap.seed
	map:Generate(true)
	MapController.ClientMap = map
	MapController.MapCreated:Fire(map)
	warn(`Part count: {map._partCount}`)

	local selectionBox = SelectionBox:Clone()
	local _, size = selectionBox:GetBoundingBox()
	selectionBox.Parent = workspace
	local spring = Spring.new(Vector3.zero)
	spring.Speed = 10

	RunService:BindToRenderStep("GetHoveredTile", 1, function(dt)
		local ray = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { workspace.Map.Tiles }
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
		if not raycastResult then
			return
		end

		local hoveredTile = map:GridPosFromWorldPos(map:SnapToGrid(raycastResult.Position))
		local building = map.buildingMap:Get(hoveredTile.X, hoveredTile.Y)
		local feature = map.featureMap:Get(hoveredTile.X, hoveredTile.Y)
		map.hoveredTile = hoveredTile
		HoveredTileLabel.Text =
			`Hovered Tile:  {map.hoveredTile}\n{building and building.Name or feature and feature.Name or "None"}`
		HoveredTileLabel.Position = UDim2.new(0.015, Mouse.X, -0.01, Mouse.Y)

		-- TODO: allow bigger selection
		spring.Target = map:WorldPosFromGridPos(hoveredTile) + Vector3.new(0, 1 + size.Y / 2, 0)
		spring:TimeSkip(dt)
		selectionBox:PivotTo(CFrame.new(spring.Position))
	end)
end)

local function updatePopulationLabel()
	PopulationLabel.Text = `Population:  {MapFolder:GetAttribute("Population")}/{MapFolder:GetAttribute("Capacity")}`
end

MapFolder:GetAttributeChangedSignal("Capacity"):Connect(updatePopulationLabel)
MapFolder:GetAttributeChangedSignal("Population"):Connect(updatePopulationLabel)

ReplicaController.RequestData()

return MapController
