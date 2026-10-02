local Hamon = require(script.Parent:WaitForChild("Hamon"))

local SUNLIGHT_YELLOW_COST = 2
local ZOOM_PUNCH_COST = 20
local BUBBLECUTTER_COST = 20
local LIFEFORCEAURA_COST = 35

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
	HamonCost = 2,
	Startup = 0.15,
	ExecuteStart = function(player)
		local character = player.Character
		if Hamon.GetHamon(character) < SUNLIGHT_YELLOW_COST then
			return
		end
		if character then
			Hamon.StartSunlightYellow(character)
		end
	end,
	ExecuteStop = function(player)
		local character = player.Character
		if character then
			Hamon.StopSunlightYellow(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 2 - RedBind (Press)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "ZoomPunch",
	Type = "Press",
	HamonCost = 20,
	Cooldown = 8,
	Startup = 0.15,
	Execute = function(player)
		local character = player.Character
		if Hamon.GetHamon(character) < ZOOM_PUNCH_COST then
			return
		end
		if character then
			Hamon.ZoomPunch(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 - CrossfireHurricane (Press)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "BubbleCutter",
	Type = "Press",
	HamonCost = 20,
	Cooldown = 8,
	Startup = 0.2,
	Execute = function(player)
		local character = player.Character
		if Hamon.GetHamon(character) < BUBBLECUTTER_COST then
			return
		end
		if character then
			Hamon.BubbleCutter(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - Hellfire (Press)
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "LifeForceAura",
	Type = "Press",
	HamonCost = 35,
	Cooldown = 8,
	Startup = 0.3,
	Execute = function(player)
		local character = player.Character
		if Hamon.GetHamon(character) < LIFEFORCEAURA_COST then
			return
		end
		if character then
			Hamon.LifeForceAura(character)
		end
	end,
}

return AbilityRegistry
