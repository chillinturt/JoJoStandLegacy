local Tusk = require(script.Parent:WaitForChild("Tusk"))

local AbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types (sent to client)
-- All abilities are Press type
--------------------------------------------------------------------
AbilityRegistry.AbilityTypes = {
	[1] = "Press",
	[2] = "Press",
	[3] = "Press",
	[4] = "Press",
}

--------------------------------------------------------------------
-- Ability 1 - NailShot
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "NailShot",
	Type = "Press",
	Cooldown = 3,
	Startup = 0.1,
	Execute = function(standModel, player)
		print("execute entered")
		local character = standModel.Parent
		if character then
			Tusk.NailShot(character)
			print("Nail shot fired")
		end
	end,
}

--------------------------------------------------------------------
-- Ability 2 - GuidedNail
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "GuidedNail",
	Type = "Press",
	Cooldown = 6,
	Startup = 0.2,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			Tusk.GuidedNail(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 - SpinWormhole
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "SpinWormhole",
	Type = "Press",
	Cooldown = 15,
	Startup = 0.3,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			Tusk.SpinWormhole(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - InfiniteRotation
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "InfiniteRotation",
	Type = "Press",
	Cooldown = 23,
	Startup = 0.45,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			Tusk.InfiniteRotation(character)
		end
	end,
}

return AbilityRegistry
