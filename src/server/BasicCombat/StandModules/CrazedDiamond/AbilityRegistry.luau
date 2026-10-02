local CrazedDiamond = require(script.Parent:WaitForChild("CrazedDiamond"))

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
-- Ability 1 - Restoration (heal ally/self, or hit an enemy caught in the touch)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "Restoration",
	Type = "Press",
	Cooldown = 11,
	Startup = 0.3,
	Execute = function(standModel, player)
		CrazedDiamond.Restoration(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - Sharpened Disc (ranged option: thrown repaired-debris projectile)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "SharpenedDisc",
	Type = "Press",
	Cooldown = 9,
	Startup = 0.25,
	Execute = function(standModel, player)
		CrazedDiamond.SharpenedDisc(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 3 - Overdrive Punch ("Dora!!") -- single devastating punch + knockback + follow-up impact
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "OverdrivePunch",
	Type = "Press",
	Cooldown = 10,
	Startup = 0.45, -- heavy haymaker wind-up ("Dora!!")
	Execute = function(standModel, player)
		CrazedDiamond.OverdrivePunch(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 4 - Perfect Repair (ultimate) -- instant AoE heal-allies/damage-enemies burst + heal aftershocks
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "PerfectRepair",
	Type = "Press",
	Cooldown = 38,
	Startup = 0.6,
	Execute = function(standModel, player)
		CrazedDiamond.PerfectRepair(standModel)
	end,
}

return AbilityRegistry
