local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local BuildController = require(script.Parent:WaitForChild("Controllers").BuildController)
local Building = require(ReplicatedStorage.Common.Building)

local buildButton = PlayerGui:WaitForChild("ScreenGui"):WaitForChild("BuildButton")
local buildMenu = PlayerGui:WaitForChild("ScreenGui"):WaitForChild("BuildMenu")

buildButton.Activated:Connect(function()
	buildButton.Visible = false
	buildMenu.Visible = true
end)

local currentButton: TextButton?
local selectedBuilding: Building.Building?
for name, _building in Building.BuildingData do
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(0.169, 0.85)
	local button = Instance.new("TextButton")
	button.Text = name
	button.Size = UDim2.fromScale(1, 1)
	button.TextScaled = true
	button.TextColor3 = Color3.new(0, 0, 0)
	button.Parent = frame
	frame.Parent = buildMenu

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
