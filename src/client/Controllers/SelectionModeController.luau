local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local GridLines = workspace:WaitForChild("Map"):WaitForChild("GridLines")

local AXE_CURSOR = "rbxassetid://81319236921332"
local BUILD_CURSOR = "rbxassetid://95764865742687"

local SelectionModeController = { SelectionMode = "None" :: SelectionMode }

-- TODO: move the code for toggling selection modes here
function SelectionModeController.SetSelectionMode(mode: SelectionMode)
	print(`SelectionModeController.SetSelectionMode({mode})`)
	SelectionModeController.SelectionMode = mode
	if mode == "None" then
		Mouse.Icon = ""
		GridLines.Texture.Transparency = 1
	elseif mode == "Build" or mode == "PlanRoad" then
		Mouse.Icon = BUILD_CURSOR
		GridLines.Texture.Transparency = 0.75
	elseif mode == "CutTree" then
		Mouse.Icon = AXE_CURSOR
		GridLines.Texture.Transparency = 1
	end
end

export type SelectionMode = "None" | "Build" | "CutTree" | "PlanRoad"
return SelectionModeController
