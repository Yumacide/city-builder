local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildController = require(script.Parent.BuildController)
local PersonController = require(script.Parent.PersonController)
local ResourceController = require(script.Parent.ResourceController)
local SelectionModeController = require(script.Parent.SelectionModeController)
local Task = require(ReplicatedStorage.Common.Task)

local CutTreeController = {}

function CutTreeController.AddCutTask(map, pos: Vector2int16)
	local tree = map.featureMap:Get(pos.X, pos.Y)
	if tree and tree.Name == "Tree" then
		for _, _task in PersonController.Tasks do
			if _task.Type == "CutTree" and _task.Location == pos then
				return
			end
		end
		local _task = Task.new("CutTree", pos, map)
		PersonController:AddTask(_task)
		_task.Completed:Connect(function()
			ResourceController:AddResource("Wood", 1)
		end)
	end
end

ContextActionService:BindAction("ToggleCutTree", function(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.End then
		return
	end

	if SelectionModeController.SelectionMode == "CutTree" then
		SelectionModeController.SetSelectionMode("None")
		ContextActionService:UnbindAction("CutTree")
		return
	end

	if SelectionModeController.SelectionMode == "Build" or SelectionModeController.SelectionMode == "PlanRoad" then
		BuildController:CancelBuilding(BuildController.SelectedBuilding)
	end

	SelectionModeController.SetSelectionMode("CutTree")
end, false, Enum.KeyCode.T)

return CutTreeController
