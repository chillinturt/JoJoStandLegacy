local HeavensDoor = require(script.Parent:WaitForChild("HeavensDoor"))
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
-- Ability 1 - PageSlash (Press)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "PageSlash",
	Type = "Press",
	Cooldown = 4,
	Startup = 0.1,
	Execute = function(standModel, player)
		HeavensDoor.PageSlash(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - ForceRead (Press)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "ForceRead",
	Type = "Press",
	Cooldown = 6,
	Startup = 0.2,
	Execute = function(standModel, player)
		HeavensDoor.ForceRead(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 3 - WriteCommand (Press)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "WriteCommand",
	Type = "Press",
	EndlagCancel = true,
	Cooldown = 6,
	Startup = 0.15,
	Execute = function(standModel, player)
		HeavensDoor.WriteCommand(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 4 - MemoryBurn (Press)
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "MemoryBurn",
	Type = "Press",
	Hyperarmor = true,
	Cooldown = 18,
	EndlagCancel = true,
	Startup = 0.4,

	Execute = function(standModel, player)
		HeavensDoor.MemoryBurn(standModel)
	end,
}

return AbilityRegistry
