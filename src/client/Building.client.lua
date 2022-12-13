local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local Mouse = Player:GetMouse()

local Buildings = ReplicatedStorage.Assets.Buildings
local Map = workspace:WaitForChild("Map")

task.wait(1) -- hack
for _, child in StarterGui:GetChildren() do
	child.Parent = PlayerGui
end

local buildButton = PlayerGui:WaitForChild("ScreenGui"):WaitForChild("BuildButton")
local buildMenu = PlayerGui:WaitForChild("ScreenGui"):WaitForChild("BuildMenu")

-- fix when origin is not 0,0
local function snapToGrid(origin: Vector3, pos: Vector3, width: number, height: number)
	return Vector3.new(
		math.round(math.clamp(pos.X, origin.X, origin.X + width)),
		pos.Y,
		math.round(math.clamp(pos.Z, origin.Z, origin.Z + height))
	)
end

buildButton.Activated:Connect(function()
	buildButton.Visible = false
	buildMenu.Visible = true
end)

local moveBuildingConnection: RBXScriptConnection
local currentButton: TextButton?
for _, frame in buildMenu:GetChildren() do
	local button = frame:FindFirstChild("TextButton")
	if not button then
		continue
	end
	-- TODO: move building to selected tile
	button.Activated:Connect(function()
		print("pressed " .. frame.Name)
		if moveBuildingConnection then
			ContextActionService:unbindAction("RotateBuilding")
			moveBuildingConnection:Disconnect()
			if currentButton == button then
				currentButton = nil
				return
			end
		end
		currentButton = button

		local building: Model = Buildings[frame.Name]:Clone()
		building.Parent = workspace
		ContextActionService:BindAction("RotateBuilding", function(_, inputState: Enum.UserInputState)
			if inputState ~= Enum.UserInputState.Begin then
				return
			end
			building.PrimaryPart.CFrame *= CFrame.Angles(0, math.rad(90), 0)
		end, false, Enum.KeyCode.R)
		moveBuildingConnection = Mouse.Move:Connect(function()
			local target = Mouse.Target
			if target.Parent ~= workspace.Map.Tiles then
				return
			end
			building:PivotTo(
				CFrame.new(
					snapToGrid(
						Map:GetAttribute("Origin"),
						Mouse.Hit.Position,
						Map:GetAttribute("Width"),
						Map:GetAttribute("Height")
					) + Vector3.new(0, 0.1, 0)
				)
			)
			print(building.PrimaryPart.Position)
		end)
	end)
end
