local FengShui = require(script.Parent:WaitForChild("FengShui"))

local AbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types (Sent to Client)
-- Types: "Press", "Hold", "Toggle"
--------------------------------------------------------------------
AbilityRegistry.AbilityTypes = {
	[1] = "Hold",
	[2] = "Press",
	[3] = "Press",
	[4] = "Press",
}

--------------------------------------------------------------------
-- Ability 1 - FlameShot (Press)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "SunlightYellow",
	Type = "Hold", -- << Add this
	Cooldown = 10, -- handled internally
	Startup = 0.15,
	ExecuteStart = function(player)
		local character = player.Character
		if character then
			FengShui.StartSunlightYellow(character)
		end
	end,
	ExecuteStop = function(player)
		local character = player.Character
		if character then
			FengShui.StopSunlightYellow(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 2 - RedBind (Press)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "FlowLikeWater",
	Type = "Press",
	Cooldown = 2,
	Execute = function(player)
		local character = player.Character
		if character then
			FengShui.FlowLikeWater(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 - CrossfireHurricane (Press)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "FlyLikeWind",
	Type = "Press",
	Cooldown = 2,
	Execute = function(player)
		local character = player.Character
		if character then
			FengShui.FlyLikeWind(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - Hellfire (Press)
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "RisingFist",
	Type = "Press",
	Cooldown = 2,
	Startup = 0.1,
	Execute = function(player)
		local character = player.Character
		if character then
			FengShui.RisingFist(character)
		end
	end,
}

return AbilityRegistry
