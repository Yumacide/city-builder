local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maid = require(ReplicatedStorage.Common.Libraries.Maid)

local Person = { Status = {
	Idle = "Idle",
	Moving = "Moving",
	Working = "Working",
	Unreachable = "Unreachable",
} }
Person.__index = Person

-- maybe start using knit components and remotecomponents and make client classes of Building and WorldMap
function Person.new(home)
	local self = setmetatable({}, Person)
	self.Home = home
	self.GridPosition = home.GridPosition
	self.Path = {} :: { Vector2int16 }
	self.Status = Person.Status.Idle
	self.Model = ReplicatedStorage.Assets.Person:Clone()
	self.Model.PrimaryPart.Color = Color3.new(math.random(), math.random(), math.random())
	self.Model:PivotTo(home.Model:GetPivot())
	self.Maid = Maid.new()
	self.Maid:GiveTask(self.Model)

	for _, part: BasePart in self.Model:GetChildren() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Person"
		end
	end

	return self
end

function Person.Destroy(self)
	self.Maid:Destroy()
end

export type Person = typeof(Person.new())

return Person
