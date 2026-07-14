local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicaController = require(ReplicatedStorage.Common.Libraries.ReplicaController)

local WorldMap = require(ReplicatedStorage.Common.WorldMap)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Player = Players.LocalPlayer

local MapFolder = workspace.Map

local ScreenGui = Player.PlayerGui:WaitForChild("ScreenGui")
local PopulationLabel = ScreenGui:WaitForChild("ResourceBar"):WaitForChild("Population"):WaitForChild("Label")

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
end)

local function updatePopulationLabel()
	PopulationLabel.Text = `Population:  {MapFolder:GetAttribute("Population")}/{MapFolder:GetAttribute("Capacity")}`
end

MapFolder:GetAttributeChangedSignal("Capacity"):Connect(updatePopulationLabel)
MapFolder:GetAttributeChangedSignal("Population"):Connect(updatePopulationLabel)

ReplicaController.RequestData()

return MapController
