local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicaController = require(ReplicatedStorage.Common.Libraries.ReplicaController)

local MapController = {}

ReplicaController.ReplicaOfClassCreated("MapReplica", function(replica)
	MapController.MapReplica = replica
end)

ReplicaController.RequestData()

return MapController
