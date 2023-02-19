return function(coords: { number }, amplitude: number, octaves: number, persistence: number)
	coords = coords or {}
	octaves = octaves or 1
	persistence = persistence or 0.5
	if #coords > 4 then
		error("The Perlin Noise API doesn't support more than 4 dimensions!")
	else
		if octaves < 1 then
			error("Octaves have to be 1 or higher!")
		else
			local X = coords[1] or 0
			local Y = coords[2] or 0
			local Z = coords[3] or 0
			local W = coords[4] or 0

			amplitude = amplitude or 10
			octaves -= 1
			if W == 0 then
				local noise = math.noise(X / amplitude, Y / amplitude, Z / amplitude)
				if octaves ~= 0 then
					for i = 1, octaves do
						local amplitudeByPersistence = amplitude * persistence ^ i
						noise += math.noise(
							X / amplitudeByPersistence,
							Y / amplitudeByPersistence,
							Z / amplitudeByPersistence
						) / 2 ^ i
					end
				end
				return noise
			else
				local AB = math.noise(X / amplitude, Y / amplitude, 0)
				local AC = math.noise(X / amplitude, Z / amplitude, 0)
				local AD = math.noise(X / amplitude, W / amplitude, 0)
				local BC = math.noise(Y / amplitude, Z / amplitude, 0)
				local BD = math.noise(Y / amplitude, W / amplitude, 0)
				local CD = math.noise(Z / amplitude, W / amplitude, 0)

				local BA = math.noise(Y / amplitude, X / amplitude, 0)
				local CA = math.noise(Z / amplitude, X / amplitude, 0)
				local DA = math.noise(W / amplitude, X / amplitude, 0)
				local CB = math.noise(Z / amplitude, Y / amplitude, 0)
				local DB = math.noise(W / amplitude, Y / amplitude, 0)
				local DC = math.noise(W / amplitude, Z / amplitude, 0)

				local ABCD = AB + AC + AD + BC + BD + CD + BA + CA + DA + CB + DB + DC

				local noise = ABCD / 12

				if octaves ~= 0 then
					for i = 1, octaves do
						local amplitudeByPersistence = amplitude * persistence ^ i
						AB = math.noise(X / amplitudeByPersistence, Y / amplitudeByPersistence, 0)
						AC = math.noise(X / amplitudeByPersistence, Z / amplitudeByPersistence, 0)
						AD = math.noise(X / amplitudeByPersistence, W / amplitudeByPersistence, 0)
						BC = math.noise(Y / amplitudeByPersistence, Z / amplitudeByPersistence, 0)
						BD = math.noise(Y / amplitudeByPersistence, W / amplitudeByPersistence, 0)
						CD = math.noise(Z / amplitudeByPersistence, W / amplitudeByPersistence, 0)

						BA = math.noise(Y / amplitudeByPersistence, X / amplitudeByPersistence, 0)
						CA = math.noise(Z / amplitudeByPersistence, X / amplitudeByPersistence, 0)
						DA = math.noise(W / amplitudeByPersistence, X / amplitudeByPersistence, 0)
						CB = math.noise(Z / amplitudeByPersistence, Y / amplitudeByPersistence, 0)
						DB = math.noise(W / amplitudeByPersistence, Y / amplitudeByPersistence, 0)
						DC = math.noise(W / amplitudeByPersistence, Z / amplitudeByPersistence, 0)

						ABCD = AB + AC + AD + BC + BD + CD + BA + CA + DA + CB + DB + DC

						noise += noise / 2 ^ i
					end
				end
				return noise
			end
		end
	end
end
