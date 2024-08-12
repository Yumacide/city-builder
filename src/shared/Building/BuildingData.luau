return {
	Road = {
		Size = Vector3.new(1, 1, 1),
		Resources = {
			Wood = 1,
		},
	},
	Keep = {
		Size = Vector3.new(2, 2, 2),
		Resources = {
			Wood = 1,
		},
	},
	Hovel = {
		Size = Vector3.new(1, 1, 1),
		Resources = {
			Wood = 1,
		},
		OnComplete = function(_self, map)
			map:UpdateCapacity()
		end,
	},
}
