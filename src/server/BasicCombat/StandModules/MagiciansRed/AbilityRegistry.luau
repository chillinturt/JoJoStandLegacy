local MagiciansRed = require(script.Parent:WaitForChild("MagiciansRed"))

local AbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types (Sent to Client)
-- Types: "Press", "Hold", "Toggle"
--------------------------------------------------------------------
AbilityRegistry.AbilityTypes = {
	[1] = "Press",
	[2] = "Press",
	[3] = "Press",
	[4] = "Press",
}

--------------------------------------------------------------------
-- Ability 1 - FlameShot (Press)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "FlameShot",
	Type = "Press",
	Cooldown = 3,
	Startup = 0.1,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			MagiciansRed.FlameShot(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 2 - RedBind (Press)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "RedBind",
	Type = "Press",
	Cooldown = 8,
	Startup = 0.25,
	Execute = function(standModel, player)
		MagiciansRed.RedBind(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 3 - CrossfireHurricane (Press)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "CrossfireHurricane",
	Type = "Press",
	Cooldown = 20,
	Startup = 0.4,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			MagiciansRed.CrossfireHurricane(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - Hellfire (Press)
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "Hellfire",
	Type = "Press",
	Cooldown = 25,
	Startup = 0.5,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			MagiciansRed.Hellfire(character)
		end
	end,
}

return AbilityRegistry
