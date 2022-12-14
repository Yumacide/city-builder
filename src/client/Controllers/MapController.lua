local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicaController = require(ReplicatedStorage.Common.Libraries.ReplicaController)

ReplicaController.ReplicaOfClassCreated("MapReplica", function(replica)
	print("MapReplica received!")
end)

ReplicaController.RequestData()

return nil
