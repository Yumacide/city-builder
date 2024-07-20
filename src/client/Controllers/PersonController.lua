local ContextActionService = game:GetService("ContextActionService")
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
			if _task.Progress >= 1 then
				data.OnComplete(_task, map)
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

local isCuttingTree = false
ContextActionService:BindAction("ToggleCutTree", function(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.End then
		return
	end

	local map = MapController:GetMap()
	if isCuttingTree then
		isCuttingTree = false
		print("Tree cutting mode off")
		ContextActionService:UnbindAction("CutTree")
		return
	end
	isCuttingTree = true
	print("Tree cutting mode on")
	ContextActionService:BindAction("CutTree", function(_, _inputState: Enum.UserInputState)
		if _inputState ~= Enum.UserInputState.End then
			return
		end
		local tree = map.featureMap[map.hoveredTile.X] and map.featureMap[map.hoveredTile.X][map.hoveredTile.Y]
		if tree and tree.Name == "Tree" then
			for _, _task in PersonController.Tasks do
				if _task.Type == "CutTree" and _task.Location == map.hoveredTile then
					return
				end
			end
			print(`Tree cutting task added at {map.hoveredTile}`)
			PersonController:AddTask(Task.new("CutTree", map.hoveredTile))
		end
	end, false, Enum.UserInputType.MouseButton1)
end, false, Enum.KeyCode.T)

export type PersonController = typeof(PersonController)

return PersonController
