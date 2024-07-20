return {
	CutTree = {
		MaxAssignees = 1,
		Time = 5,
		OnComplete = function(self, map)
			map.featureMap:Get(self.Location.X, self.Location.Y):Destroy()
			map.featureMap:Set(self.Location.X, self.Location.Y, nil)
			print(`Done cutting tree at {self.Location}`)
		end,
	},
}
