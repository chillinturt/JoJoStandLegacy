local ThatHand = require(script.Parent:WaitForChild("ThatHand"))

local AbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types (sent to the client)
-- All of these abilities are "Press"
--------------------------------------------------------------------
AbilityRegistry.AbilityTypes = {
	[1] = "Press",
	[2] = "Press",
	[3] = "Press",
	[4] = "Press",
}

--------------------------------------------------------------------
-- Ability 1 - Erase
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "Erase",
	Type = "Press",
	Cooldown = 8,
	Startup = 0.25,
	Execute = function(standModel, player)
		ThatHand.Erase(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - VoidShielding
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "VoidShielding",
	Type = "Press",
	Cooldown = 16,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			ThatHand.VoidShielding(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 - TearSpace
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "TearSpace",
	Type = "Press",
	Cooldown = 12,
	Startup = 0.3,
	Execute = function(standModel, player)
		ThatHand.TearSpace(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 4 - LastStand
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "LastStand",
	Type = "Press",
	Cooldown = 28,
	Startup = 0.5,
	Execute = function(standModel, player)
		ThatHand.LastStand(standModel)
	end,
}

return AbilityRegistry
