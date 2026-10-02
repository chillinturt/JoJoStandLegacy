local HermitPurple = require(script.Parent:WaitForChild("HermitPurple"))
local CombatUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))

local AbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types (Sent to Client)
-- Types: "Press", "Hold", "Toggle"
--------------------------------------------------------------------
AbilityRegistry.AbilityTypes = {
	[1] = "Press",
	[2] = "Hold",
	[3] = "Press",
	[4] = "Press",
}

--------------------------------------------------------------------
-- Ability 1 - Puppet Master (Press)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "PuppetMaster",
	Type = "Press", -- << Add this
	Cooldown = 10,
	Startup = 0.25,
	Execute = function(standModel, player)
		HermitPurple.PuppetMaster(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - Grapple (Hold)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "Grapple",
	Type = "Hold", -- << Add this
	Cooldown = 10, -- handled internally
	Startup = 0.15,
	ExecuteStart = function(standModel, player)
		local character = standModel.Parent
		if character then
			HermitPurple.StartGrapple(character)
		end
	end,
	ExecuteStop = function(standModel, player)
		local character = standModel.Parent
		if character then
			HermitPurple.StopGrapple(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 - Emerald Barrier (Press)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "EmeraldBarrier",
	Type = "Press", -- << Add this
	Cooldown = 12,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			HermitPurple.ActivateBarrier(standModel)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - Twenty Meter Barrier (Press)
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "TwentyMeterBarrier",
	Type = "Press", -- << Add this
	Cooldown = 40,
	Execute = function(standModel, player)
		HermitPurple.TwentyMeterBarrier(standModel)
	end,
}

return AbilityRegistry
