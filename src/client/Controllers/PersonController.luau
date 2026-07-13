local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MapController = require(script.Parent.MapController)
local Building = require(ReplicatedStorage.Common.Building)
local Person = require(ReplicatedStorage.Common.Person)
local Task = require(ReplicatedStorage.Common.Task)

local PERSON_WALKSPEED = 4

-- TODO: stop using humanoids, instead implement pathfinding and move people manually

local PersonController = {
	People = {} :: { Person.Person },
	Tasks = {} :: { Task.Task },
}

function PersonController.AddTask(self: PersonController, _task: Task.Task)
	table.insert(self.Tasks, _task)
	self:UpdateTasks()
end

function PersonController.UpdateTasks(self: PersonController)
	-- TODO: make it so each person selects the task closest to them
	for _, _task in self.Tasks do
		if #_task.Assignees == Task.TaskData[_task.Type].MaxAssignees then
			continue
		end

		for _, person in self.People do
			if person.AssignedTask then
				continue
			end

			person.AssignedTask = _task
			table.insert(_task.Assignees, person)

			if #_task.Assignees == Task.TaskData[_task.Type].MaxAssignees then
				break
			end
		end
	end
end

function PersonController.MoveToTask(self: PersonController, person: Person.Person)
	person.Status = Person.Status.Moving
	local map = MapController:GetMap()
	local path = map:FindPath(person.GridPosition, person.AssignedTask.Location)
	if not path then
		person.Status = Person.Status.Unreachable
		return
	end

	local _, size = person.Model:GetBoundingBox()
	person.Path = path
	task.spawn(function()
		local previousNode = person.GridPosition
		for _ = 1, #person.Path do
			local node = person.Path[1]
			local offset = node - previousNode
			local distance = math.sqrt(offset.X ^ 2 + offset.Y ^ 2)
			local tween = TweenService:Create(
				person.Model.PrimaryPart,
				TweenInfo.new(distance / PERSON_WALKSPEED, Enum.EasingStyle.Linear),
				{ CFrame = CFrame.new(map:WorldPosFromGridPos(node) + Vector3.new(0, 0.5 + size.Y)) }
			)
			tween:Play()
			tween.Completed:Wait()
			table.remove(person.Path, 1)
			previousNode = node
		end
		self:StartWork(person)
	end)
end

function PersonController.StartWork(_: PersonController, person: Person.Person)
	person.Status = Person.Status.Working
	local map = MapController:GetMap()
	local _, size = person.Model:GetBoundingBox()
	person.Model.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
	person.Model:PivotTo(
		CFrame.new(map:WorldPosFromGridPos(person.AssignedTask.Location) + Vector3.new(0, size.Y + 0.5, 0))
	)
	table.insert(person.AssignedTask.AssigneesWorking, person)
end

function PersonController.SimulatePeople(self: PersonController, dt: number)
	local map = MapController:GetMap()
	for _, person: Person.Person in self.People do
		person.GridPosition = map:GridPosFromWorldPos(map:SnapToGrid(person.Model:GetPivot().Position))
		if not person.AssignedTask then
			continue
		end

		if person.Status == Person.Status.Idle then
			self:MoveToTask(person)
		end
	end

	for _, _task in self.Tasks do
		local data = Task.TaskData[_task.Type]
		if #_task.AssigneesWorking > 0 then
			_task.Progress += (dt / data.Time) * #_task.AssigneesWorking / data.MaxAssignees
			data.OnUpdate(_task, map, dt)
			if _task.Progress >= 1 then
				_task:Complete()
				for _, person in _task.Assignees do
					person.AssignedTask = nil
					person.Status = Person.Status.Idle
				end
				table.remove(self.Tasks, table.find(self.Tasks, _task))
			end
		end
	end
end

function PersonController.AddPerson(self: PersonController, home: Building.Building)
	local person = Person.new(home)
	person.Model.Parent = workspace
	table.insert(self.People, person)
end

function PersonController.RemovePerson(self: PersonController, person: Person.Person)
	person:Destroy()
	table.remove(self.People, table.find(self.People, person))
	if person.AssignedTask then
		table.remove(person.AssignedTask.Assignees, table.find(person.AssignedTask.Assignees, person))
	end
end

task.spawn(function()
	while true do
		PersonController:SimulatePeople(task.wait(0.5))
		PersonController:UpdateTasks()
	end
end)

export type PersonController = typeof(PersonController)

return PersonController
