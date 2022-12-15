local PathNode = {}
PathNode.__index = PathNode

function PathNode.__eq(a: PathNode, b: PathNode)
	return a.Position == b.Position
end

function PathNode.new(pos: Vector2int16, parent: PathNode?)
	local self = setmetatable({}, PathNode)

	self.Position = pos
	self.Parent = parent

	self.g = 0
	self.h = 0

	return self
end

function PathNode:GetNeighbors(): { PathNode }
	return {
		PathNode.new(Vector2int16.new(self.Position.X + 1, self.Position.Y)),
		PathNode.new(Vector2int16.new(self.Position.X - 1, self.Position.Y)),
		PathNode.new(Vector2int16.new(self.Position.X, self.Position.Y + 1)),
		PathNode.new(Vector2int16.new(self.Position.X, self.Position.Y - 1)),
	}
end

function PathNode:EstimateCost(otherNode: PathNode)
	local delta = self.Position - otherNode.Position
	return math.abs(delta.X) + math.abs(delta.Y)
end

export type PathNode = typeof(PathNode.new(Vector2int16.new(0, 0), nil))

return PathNode
