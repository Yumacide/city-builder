local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local BuildController = require(script.Parent:WaitForChild("Controllers").BuildController)
local Building = require(ReplicatedStorage.Common.Building)

task.wait(1) -- hack
for _, child in StarterGui:GetChildren() do
	child.Parent = PlayerGui
end

local buildButton = PlayerGui:WaitForChild("ScreenGui"):WaitForChild("BuildButton")
local buildMenu = PlayerGui:WaitForChild("ScreenGui"):WaitForChild("BuildMenu")

buildButton.Activated:Connect(function()
	buildButton.Visible = false
	buildMenu.Visible = true
end)

local currentButton: TextButton?
local selectedBuilding: Building.Building?
for _, frame in buildMenu:GetChildren() do
	local button = frame:FindFirstChild("TextButton")
	if not button then
		continue
	end
	-- TODO: move building to selected tile
	button.Activated:Connect(function()
		if currentButton then
			selectedBuilding:Destroy()
			if currentButton == button then
				currentButton = nil
				selectedBuilding = nil
				return
			end
		end

		selectedBuilding = Building.new(frame.Name)
		BuildController:Plan(selectedBuilding, true)
		currentButton = button

		selectedBuilding.Placed:Connect(function()
			selectedBuilding = nil
			currentButton = nil
		end)

		selectedBuilding.Destroying:Connect(function()
			selectedBuilding = nil
			currentButton = nil
		end)
	end)
end
