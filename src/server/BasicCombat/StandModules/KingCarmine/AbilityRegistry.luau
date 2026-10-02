local KingCarmine = require(script.Parent:WaitForChild("KingCarmine"))
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
	Cooldown = 8,
	Startup = 0.2,
	Execute = function(standModel, player)
		KingCarmine.Chop(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - Splatter (Press)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "Splatter",
	Type = "Press",
	Cooldown = 10,
	Startup = 0.3,
	Execute = function(standModel, player)
		KingCarmine.Splatter(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 3 - Teleport (Press)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "Teleport",
	Type = "Press",
	EndlagCancel = true,
	Cooldown = 8,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			KingCarmine.Teleport(character)
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

	BypassGlobalCooldown = true,
	-- No Startup here on purpose: Execute is a self-managed activate/cancel
	-- state machine, and the second-press cancel must stay instant. See
	-- AbilityHandler's waitForStartup comment.

	Execute = function(standModel, player)
		local character = standModel.Parent
		if not character then
			return
		end

		local now = tick()

		-- SECOND PRESS: cancel
		if KingCarmine.IsTimeEraseActive(player) then
			KingCarmine.CancelTimeErase(character)
			return
		end

		-- cooldown check
		local lastUse = lastTimeEraseUse[player] or 0
		if now - lastUse < 30 then
			return
		end

		-- activate
		KingCarmine.TimeErase(standModel)

		lastTimeEraseUse[player] = now
		CooldownUpdateEvent:FireClient(player, 4, 30)
	end,
}

return AbilityRegistry
