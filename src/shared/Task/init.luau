local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Person = require(script.Parent.Person)
local WorldMap = require(script.Parent.WorldMap)

local Task = {}
Task.__index = Task

Task.TaskData = require(script.TaskData)

function Task.new(type: string, location: Vector2int16, map: WorldMap.WorldMap)
	local self = setmetatable({}, Task)
	self.Type = type
	self.Location = location
	self.Progress = 0
	self.Assignees = {} :: { Person.Person }
	self.AssigneesWorking = {} :: { Person.Person }
	self.Completed = Signal.new()
	self.Map = map
	Task.TaskData[type].OnCreate(self, map)

	return self
end

function Task.Complete(self: Task)
	self.Completed:Fire()
	Task.TaskData[self.Type].OnComplete(self, self.Map)
end

export type Task = typeof(Task.new("", Vector2int16.new(0, 0), WorldMap.new(Vector3.new(0, 0, 0), 0, 0)))

return Task
