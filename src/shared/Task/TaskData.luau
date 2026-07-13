local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- I don't like how all the axes shake in sync. Make it so that each axe shakes independently.

return {
	CutTree = {
		MaxAssignees = 1,
		Time = 5,
		OnCreate = function(self, map)
			local tree = map.featureMap:Get(self.Location.X, self.Location.Y)
			local axe = ReplicatedStorage.Assets.Axe:Clone()
			axe:PivotTo(tree:GetPivot() + Vector3.new(0, 2, 0))
			axe.Parent = tree

			self.CFrame = axe:GetPivot()
			self.Axe = axe
		end,
		OnUpdate = function(self, map, dt)
			task.spawn(function()
				-- shake axe with spring
				local animationTime = 0.25
				local timeElapsed = 0
				local dt2 = 0
				local shakeDirection = Vector3.new(math.random(), 0, math.random()).Unit
				print("shake axe")
				while true do
					if timeElapsed >= animationTime then
						break
					end

					self.Axe:PivotTo(
						self.CFrame + shakeDirection * math.sin((2 * math.pi / animationTime) * timeElapsed) * 0.25
					)
					dt2 = task.wait()
					timeElapsed += dt2
				end
			end)
		end,
		OnComplete = function(self, map)
			map.featureMap:Get(self.Location.X, self.Location.Y):Destroy()
			map.featureMap:Set(self.Location.X, self.Location.Y, nil)
			print(`Done cutting tree at {self.Location}`)
		end,
	},
}
