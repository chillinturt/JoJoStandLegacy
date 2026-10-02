-- Default off-stand (bare-handed) ability registry. Active for every player
-- whenever they have no stand summoned, completely independent of hero,
-- stand, race, or specialty. Bound to the same T/R/Z/X keybinds as the
-- on-stand registries, but tracked under its own cooldown/hold namespace by
-- AbilityHandler so the two sets never collide.
--
-- Later this can become one of several selectable off-stand loadouts; for now
-- every player gets this same default kit (see AbilityHandler.getOffAbilityRegistry).
local OffAbilities = require(script.Parent:WaitForChild("OffAbilities"))

local OffAbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types
--------------------------------------------------------------------
OffAbilityRegistry.AbilityTypes = {
	[1] = "Press",
	[2] = "Press",
	[3] = "Press",
	[4] = "Toggle",
}

--------------------------------------------------------------------
-- Ability 1 - Jab
--------------------------------------------------------------------
OffAbilityRegistry[1] = {
	Name = "Jab",
	Type = "Press",
	Cooldown = 10,
	Execute = function(character, player)
		if character then
			OffAbilities.Jab(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 2 - Grapple
--------------------------------------------------------------------
OffAbilityRegistry[2] = {
	Name = "Grapple",
	Type = "Press",
	Cooldown = 12,
	Startup = 0.2,
	Execute = function(character, player)
		if character then
			OffAbilities.Grapple(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 - Rush
--------------------------------------------------------------------
OffAbilityRegistry[3] = {
	Name = "Rush",
	Type = "Press",
	Cooldown = 7,
	Startup = 0.15,
	Execute = function(character, player)
		if character then
			OffAbilities.Rush(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - Flurry (toggled barrage)
--------------------------------------------------------------------
OffAbilityRegistry[4] = {
	Name = "Flurry",
	Type = "Toggle",
	Cooldown = 16,
	Startup = 0.2,
	ExecuteStart = function(character, player)
		if character then
			OffAbilities.FlurryStart(character)
		end
	end,
	ExecuteStop = function(character, player)
		if character then
			OffAbilities.FlurryStop(character)
		end
	end,
}

return OffAbilityRegistry
