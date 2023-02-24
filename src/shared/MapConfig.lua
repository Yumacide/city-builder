local function resizeY(part: BasePart, size: number)
	part.Position = part.Position + Vector3.new(0, math.abs(part.Size.Z - size) / 2, 0)
	part.Size = Vector3.new(1, size, 1)
end

return {
	Biomes = {
		Desert = {
			Humidity = 0,
			Temperature = 1,
			Levels = {
				Sand = {
					Height = 0,
					Modify = function(part: BasePart)
						part.Color = Color3.fromRGB(227, 216, 182)
					end,
				},
			},
		},
		Snow = {
			Humidity = 1,
			Temperature = 0.5,
			Levels = {
				Snow = {
					Height = 0,
					Modify = function(part: BasePart)
						part.Color = Color3.fromRGB(238, 238, 238)
					end,
				},
				LightSnow = {
					Modify = function(part: BasePart)
						part.Color = Color3.fromRGB(163, 236, 254)
					end,
				},
			},
		},
		Plains = {
			Levels = {
				Mountain = {
					Height = 0.5,
					Modify = function(part: BasePart, noise: number)
						part.Color = Color3.fromRGB(64, 64, 64)
						resizeY(part, 5 * (noise + 0.5))
						part.Position += Vector3.new(0, 1, 0)
					end,
					NotGreedy = true,
					Impassable = true,
				},
				Green = {
					Height = -0.2,
					Modify = function(part: BasePart)
						part.Color = Color3.fromRGB(90, 159, 95)
					end,
				},
				LightGreen = {
					Height = -0.4,
					Modify = function(part: BasePart)
						part.Color = Color3.fromRGB(107, 215, 116)
					end,
				},
				Beach = {
					Height = -0.45,
					Modify = function(part: BasePart)
						part.Color = Color3.fromRGB(227, 216, 182)
					end,
				},
			},
			Humidity = 0.5,
			Temperature = 0.5,
		},
	},
}
