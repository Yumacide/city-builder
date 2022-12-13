-- TODO: maybe make it so the stored data for next frame is ground pos, rotation and height
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local CAMERA_ANGLE = math.rad(45)
local MOVEMENT_VECTORS = {
	[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
}
local MOVEMENT_SPEED = 50

Camera.CameraType = Enum.CameraType.Scriptable
Camera.CFrame = CFrame.new(50, 20, 50) * CFrame.Angles(-CAMERA_ANGLE, 0, 0)

local tween: Tween
local shouldRotateCamera: boolean
local currentRotation = 0
local nextCameraCFrame = Camera.CFrame

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if nextCameraCFrame.Y < 20 and input.Position.Z > 0 or nextCameraCFrame.Y > 50 and input.Position.Z < 0 then
			return
		end
		nextCameraCFrame *= CFrame.new(0, 0, -input.Position.Z * 10)
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
	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		print("should rotate")
		shouldRotateCamera = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton3 then
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

RunService.Heartbeat:Connect(function()
	if Camera.CFrame == nextCameraCFrame then
		return
	end
	-- Keep camera in bounds
	local yDistance = nextCameraCFrame.Y - 1.5
	local distance = yDistance / math.sin(CAMERA_ANGLE)
	local zDistance = yDistance / math.tan(CAMERA_ANGLE)
	local groundPos = nextCameraCFrame * Vector3.new(0, 0, -distance)
	groundPos = Vector3.new(math.clamp(groundPos.X, 0, 250), groundPos.Y, math.clamp(groundPos.Z, 0, 250))
	local cameraPos = CFrame.new(groundPos)
		* CFrame.Angles(0, currentRotation, 0)
		* Vector3.new(0, yDistance, zDistance)
	nextCameraCFrame = CFrame.lookAt(cameraPos, groundPos)

	Camera.CFrame = nextCameraCFrame
end)
