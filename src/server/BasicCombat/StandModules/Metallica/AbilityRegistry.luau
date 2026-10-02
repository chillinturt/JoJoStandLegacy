local Metallica = require(script.Parent:WaitForChild("Metallica"))

local AbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types (Sent to Client)
-- Types: "Press", "Hold", "Toggle"
--------------------------------------------------------------------
AbilityRegistry.AbilityTypes = {
	[1] = "Toggle",
	[2] = "Press",
	[3] = nil, -- unfinished
	[4] = nil, -- unfinished
}

--------------------------------------------------------------------
-- Ability 1 - MagneticAura (Toggle)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "MagneticAura",
	Type = "Toggle",
	Cooldown = 1,
	Startup = 0.15,
	ExecuteStart = function(standModel, player)
		Metallica.StartMagneticAura(standModel)
	end,
	ExecuteStop = function(standModel, player)
		Metallica.StopMagneticAura(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - ScalpelDaggers (Press)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "ScalpelDaggers",
	Type = "Press",
	Cooldown = 8,
	Startup = 0.25,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			Metallica.ScalpelDaggers(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 & 4 - Unfinished
--------------------------------------------------------------------
--[[
AbilityRegistry[3] = {
	Name = "ScalpelDaggers",
	Type = "Press",
	Cooldown = 8,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			-- Metallica.ScalpelDaggers(standModel)
		end
	end,
}

AbilityRegistry[4] = {
	Name = "Hellfire",
	Type = "Press",
	Cooldown = 20,
	Execute = function(standModel, player)
		-- Metallica.Hellfire(standModel)
	end,
}
]]

return AbilityRegistry
