local KaiserQueen = require(script.Parent:WaitForChild("KaiserQueen"))

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
	Name = "PlantBomb",
	Type = "Press",
	Cooldown = 1,
	Execute = function(standModel, player)
		KaiserQueen.PlantBomb(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - VoidShielding
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "SheerHeartAttack",
	Type = "Press",
	Cooldown = 9,
	Startup = 0.2,
	Execute = function(standModel, player)
		KaiserQueen.SheerHeartAttack(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 3 - TearSpace
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "StrayCatBubble",
	Type = "Press",
	Cooldown = 15,
	Startup = 0.3,
	Execute = function(standModel, player)
		KaiserQueen.StrayCatBubble(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 4 - LastStand
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "BitesTheDust",
	Type = "Press",
	Cooldown = 2,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			KaiserQueen.BitesTheDust(character)
		end
	end,
}

return AbilityRegistry
