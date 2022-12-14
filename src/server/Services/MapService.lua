local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicaService = require(ServerScriptService.Libraries.ReplicaService)
local WorldMap = require(ReplicatedStorage.Common.WorldMap)

local BuildingPlaced = ReplicatedStorage.Remotes.BuildingPlaced

Players.PlayerAdded:Connect(function(player)
	local map = WorldMap.new(Vector3.new(0, 1, 0), 250, 250)
	map:Generate()
	warn("Part count: " .. map._partCount)

	local mapReplica = ReplicaService.NewReplica({
		ClassToken = ReplicaService.NewClassToken("MapReplica"),
		Data = { Owner = player, Map = map },
		Replication = { [player] = true },
	})
end)

BuildingPlaced.OnServerEvent:Connect(function(player) end)

return nil
