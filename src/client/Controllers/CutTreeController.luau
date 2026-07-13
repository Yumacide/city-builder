local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PersonController = require(script.Parent.PersonController)
local Task = require(ReplicatedStorage.Common.Task)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local AxeCursor = "rbxassetid://81319236921332"

local CutTreeController = { isCutMode = false }

function CutTreeController.AddCutTask(map, pos: Vector2int16)
	local tree = map.featureMap:Get(pos.X, pos.Y)
	if tree and tree.Name == "Tree" then
		for _, _task in PersonController.Tasks do
			if _task.Type == "CutTree" and _task.Location == pos then
				return
			end
		end
		PersonController:AddTask(Task.new("CutTree", pos, map))
	end
end

ContextActionService:BindAction("ToggleCutTree", function(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.End then
		return
	end

	if CutTreeController.isCutMode then
		CutTreeController.isCutMode = false
		Mouse.Icon = "rbxasset://SystemCursors/Arrow"
		ContextActionService:UnbindAction("CutTree")
		return
	end
	CutTreeController.isCutMode = true
	Mouse.Icon = AxeCursor
end, false, Enum.KeyCode.T)

return CutTreeController
