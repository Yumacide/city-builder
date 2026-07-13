local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapController = require(script.Parent:WaitForChild("Controllers").MapController)
local PersonController = require(script.Parent:WaitForChild("Controllers").PersonController)
local Task = require(ReplicatedStorage.Common.Task)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local AxeCursor = "rbxthumb://type=Asset&id=94089333002842&w=150&h=150"

local isCuttingTree = false
ContextActionService:BindAction("ToggleCutTree", function(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.End then
		return
	end

	local map = MapController:GetMap()
	if isCuttingTree then
		isCuttingTree = false
		print("Tree cutting mode off")
		Mouse.Icon = "rbxasset://SystemCursors/Arrow"
		ContextActionService:UnbindAction("CutTree")
		return
	end
	isCuttingTree = true
	print("Tree cutting mode on")
	Mouse.Icon = AxeCursor
	print(Mouse.Icon)
	ContextActionService:BindAction("CutTree", function(_, _inputState: Enum.UserInputState)
		if _inputState ~= Enum.UserInputState.End then
			return
		end
		local tree = map.featureMap:Get(map.hoveredTile.X, map.hoveredTile.Y)
		if tree and tree.Name == "Tree" then
			for _, _task in PersonController.Tasks do
				if _task.Type == "CutTree" and _task.Location == map.hoveredTile then
					return
				end
			end
			print(`Tree cutting task added at {map.hoveredTile}`)
			PersonController:AddTask(Task.new("CutTree", map.hoveredTile, map))
		end
	end, false, Enum.UserInputType.MouseButton1)
end, false, Enum.KeyCode.T)
