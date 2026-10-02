local StickyFingers = require(script.Parent:WaitForChild("StickyFingers"))
local CombatUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))

local CooldownUpdateEvent = game.ReplicatedStorage
	:WaitForChild("Shared")
	:WaitForChild("BasicCombat")
	:WaitForChild("UI")
	:WaitForChild("CooldownUpdateEvent")

local AbilityRegistry = {}

local lastTimeEraseUse = {}

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
-- Ability 1 - Chop (Press)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "Chop",
	Type = "Press",
	Cooldown = 10,
	Startup = 0.2,
	Execute = function(standModel, player)
		StickyFingers.Barrage(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - Splatter (Press)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "Splatter",
	Type = "Press",
	Cooldown = 12,
	Startup = 0.25,
	Execute = function(standModel, player)
		StickyFingers.ZipperTrap(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 3 - Teleport (Press)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "Teleport",
	Type = "Press",
	EndlagCancel = true,
	Cooldown = 12,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			StickyFingers.ZipperDash(character)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - TimeErase (Press)
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "TimeErase",
	Type = "Press",
	Hyperarmor = true,
	Cooldown = 30,
	EndlagCancel = true,
	Startup = 0.35,

	BypassGlobalCooldown = true,

	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			StickyFingers.ZipperPull()
		end
	end,
}

return AbilityRegistry
