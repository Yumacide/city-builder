local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local ScreenGui = PlayerGui:WaitForChild("ScreenGui")
local WoodLabel: TextLabel = ScreenGui:WaitForChild("Wood")

local ResourceController = {
	Resources = {
		Wood = 0,
	},
}

function ResourceController.AddResource(
	self: ResourceController,
	resource: "Wood",
	amount: number,
	_location: Vector2int16?
)
	print(`Adding {amount} {resource} to inventory`)
	self.Resources[resource] += amount
	if resource == "Wood" then
		WoodLabel.Text = "Wood: " .. self.Resources[resource]
	end
end

export type ResourceController = typeof(ResourceController)
return ResourceController
