local NuclearRain = require(script.Parent:WaitForChild("NuclearRain"))
local CombatUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))

local AbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types (Sent to Client)
-- Types: "Press", "Hold", "Toggle"
--------------------------------------------------------------------
AbilityRegistry.AbilityTypes = {
	[1] = "Toggle",
	[2] = "Press",
	[3] = "Press", -- unfinished
	[4] = "Press", -- unfinished
}

--------------------------------------------------------------------
-- Ability 1 - TorrentialDownpour (Toggle)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "TorrentialDownpour",
	Type = "Toggle",
	EndlagCancel = true,
	Cooldown = 1,
	Startup = 0.2,
	ExecuteStart = function(standModel, player)
		NuclearRain.StartTorrentialDownpour(standModel)
	end,
	ExecuteStop = function(standModel, player)
		NuclearRain.StopTorrentialDownpour(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - HeavyRaindrop (Press)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "HeavyRaindrop",
	Type = "Press",
	EndlagCancel = true,
	Cooldown = 8,
	Startup = 0.25,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			NuclearRain.HeavyRaindrop(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 & 4 - Unfinished
--------------------------------------------------------------------

AbilityRegistry[3] = {
	Name = "ExpelBarrier",
	Type = "Press",
	Cooldown = 8,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			NuclearRain.ExpelBarrier(character)
		end
	end,
}

AbilityRegistry[4] = {
	Name = "RainCage",
	Type = "Press",
	Cooldown = 25,
	Startup = 0.4,
	Execute = function(standModel, player)
		local character = standModel.Parent
		-- 1️⃣ Read barrier FIRST
		local barrierDamage = CombatUtils.GetTotalBarrier(character)
		if barrierDamage < 0 then
			return
		end
		if character then
			NuclearRain.LiquidCage(character)
		end
	end,
}

return AbilityRegistry
