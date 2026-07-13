local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PersonController = require(script.Parent.PersonController)
local ResourceController = require(script.Parent.ResourceController)
local SelectionModeController = require(script.Parent.SelectionModeController)
local Task = require(ReplicatedStorage.Common.Task)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local AxeCursor = "rbxassetid://81319236921332"

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
		SelectionModeController.SelectionMode = "None"
		Mouse.Icon = ""
		ContextActionService:UnbindAction("CutTree")
		return
	end
	SelectionModeController.SelectionMode = "CutTree"
	Mouse.Icon = AxeCursor
end, false, Enum.KeyCode.T)

return CutTreeController
