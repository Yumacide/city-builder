-- FIX: make it so rotation doesn't wrap around
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Camera = workspace.CurrentCamera

local Spring = require(ReplicatedStorage.Common:WaitForChild("Libraries"):WaitForChild("Spring"))

local CAMERA_ANGLE = math.rad(45)
local MOVEMENT_VECTORS = {
	[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
}
local MOVEMENT_SPEED = 50
local MIN_HEIGHT, MAX_HEIGHT = 10, 80

Camera.CameraType = Enum.CameraType.Scriptable
Camera.CFrame = CFrame.new(125, 40, 125) * CFrame.Angles(-CAMERA_ANGLE, 0, 0)

local positionSpring = Spring.new(Camera.CFrame.Position)
local anglesSpring = Spring.new(Vector3.new(Camera.CFrame:ToEulerAnglesXYZ()))
positionSpring.Speed = 10
anglesSpring.Speed = 15

local shouldRotateCamera: boolean
local currentRotation = 0
local nextCameraCFrame = Camera.CFrame

local function _getClosestAngle(new: number, old: number)
	while math.abs(new - old) > math.pi do
		if new > old then
			new -= math.pi * 2
		else
			new += math.pi * 2
		end
	end

	return new
end

local function getClosestAngles(new: Vector3, old: Vector3)
	return Vector3.new(_getClosestAngle(new.X, old.X), _getClosestAngle(new.Y, old.Y), _getClosestAngle(new.Z, old.Z))
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if
			nextCameraCFrame.Y < MIN_HEIGHT and input.Position.Z > 0
			or nextCameraCFrame.Y > MAX_HEIGHT and input.Position.Z < 0
		then
			return
		end
		nextCameraCFrame *= CFrame.new(0, 0, -input.Position.Z * 5)
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		if shouldRotateCamera then
			-- This isn't optimal, but it works
			local yDistance = nextCameraCFrame.Y - 1.5
			local distance = yDistance / math.sin(CAMERA_ANGLE)
			local zDistance = yDistance / math.tan(CAMERA_ANGLE)
			local groundPos = nextCameraCFrame * Vector3.new(0, 0, -distance)
			currentRotation -= input.Delta.X * 0.005
			local cameraPos = CFrame.new(groundPos)
				* CFrame.Angles(0, currentRotation, 0)
				* Vector3.new(0, yDistance, zDistance)
			nextCameraCFrame = CFrame.lookAt(cameraPos, groundPos)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		shouldRotateCamera = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		shouldRotateCamera = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	local movementVector = Vector3.zero
	for keyCode, vector in pairs(MOVEMENT_VECTORS) do
		if UserInputService:IsKeyDown(keyCode) then
			movementVector += vector
		end
	end
	if movementVector == Vector3.zero then
		return
	end
	local cameraForward = nextCameraCFrame * CFrame.Angles(CAMERA_ANGLE, 0, 0)
	nextCameraCFrame = cameraForward
		* CFrame.new(movementVector * MOVEMENT_SPEED * deltaTime)
		* CFrame.Angles(-CAMERA_ANGLE, 0, 0)
end)

RunService.Stepped:Connect(function(_, deltaTime)
	if Camera.CFrame.Position:FuzzyEq(nextCameraCFrame.Position, 0.001) then
		return
	end

	local yDistance = nextCameraCFrame.Y - 1.5
	local distance = yDistance / math.sin(CAMERA_ANGLE)
	local zDistance = yDistance / math.tan(CAMERA_ANGLE)
	local groundPos = nextCameraCFrame * Vector3.new(0, 0, -distance)
	groundPos = Vector3.new(math.clamp(groundPos.X, 0, 250), groundPos.Y, math.clamp(groundPos.Z, 0, 250))
	local cameraPos = CFrame.new(groundPos)
		* CFrame.Angles(0, currentRotation, 0)
		* Vector3.new(0, yDistance, zDistance)
	nextCameraCFrame = CFrame.lookAt(cameraPos, groundPos)

	local positionGoal = nextCameraCFrame.Position
	local anglesGoal = getClosestAngles(Vector3.new(nextCameraCFrame:ToOrientation()), anglesSpring.Position)

	positionSpring.Target = positionGoal
	anglesSpring.Target = anglesGoal

	positionSpring:TimeSkip(deltaTime)
	anglesSpring:TimeSkip(deltaTime)

	Camera.CFrame = CFrame.new(positionSpring.Position)
		* CFrame.fromOrientation(anglesSpring.Position.X, anglesSpring.Position.Y, anglesSpring.Position.Z)
end)
