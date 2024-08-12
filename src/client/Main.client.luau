local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

for _, child in StarterGui:GetChildren() do
	child.Parent = PlayerGui
end
StarterGui.ChildAdded:Connect(function(child)
	child.Parent = PlayerGui
end)

for _, controller in script.Parent:WaitForChild("Controllers"):GetChildren() do
	task.spawn(require, controller)
end
