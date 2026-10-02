local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cream = require(script.Parent:WaitForChild("Cream"))
local CooldownUpdateEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("CooldownUpdateEvent")

-- ====================================================================
-- DarkSpace charge state (2 independent charges, each recharges on its own timer)
-- ====================================================================
local DARKSPACE_RECHARGE_TIME = 9

local darkSpaceCharges = {} -- [player] = { readyTimes = { t1, t2 } }

local function getDarkSpaceState(player)
	local state = darkSpaceCharges[player]
	if not state then
		state = { readyTimes = { 0, 0 } }
		darkSpaceCharges[player] = state
	end
	return state
end

-- ====================================================================
-- Registry
-- ====================================================================
local AbilityRegistry = {}

--------------------------------------------------------------------
-- Ability Types (all Press)
--------------------------------------------------------------------
AbilityRegistry.AbilityTypes = {
	[1] = "Press",
	[2] = "Press",
	[3] = "Press",
	[4] = "Press",
}

--------------------------------------------------------------------
-- Ability 1 - DarkSpace (2 charges)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "DarkSpace",
	Type = "Press",
	Cooldown = 0,
	Startup = 0.2,

	-- We manage our own per-charge cooldown below
	BypassGlobalCooldown = true,

	Execute = function(standModel, player)
		local character = standModel.Parent
		if not character then
			return
		end

		local state = getDarkSpaceState(player)
		table.sort(state.readyTimes)

		local now = tick()
		if state.readyTimes[1] > now then
			return -- no charges available yet
		end

		local success = Cream.DarkSpace(character)
		if not success then
			return
		end

		-- Consume a charge and start its recharge timer
		state.readyTimes[1] = now + DARKSPACE_RECHARGE_TIME
		table.sort(state.readyTimes)

		local remaining = math.max(0, state.readyTimes[1] - now)
		CooldownUpdateEvent:FireClient(player, 1, remaining)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - HowsThat (grab & flurry)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "HowsThat",
	Type = "Press",
	Cooldown = 14,
	Startup = 0.3,
	Execute = function(standModel, player)
		local char = standModel.Parent
		if char then
			Cream.HowsThat(char)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 - VoidLeap
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "VoidLeap",
	Type = "Press",
	Cooldown = 10,
	Startup = 0.2,
	Execute = function(standModel, player)
		local char = standModel.Parent
		if char then
			Cream.VoidLeap(char)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - MadnessSorrow (ultimate)
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "MadnessSorrow",
	Type = "Press",
	Cooldown = 23,
	Startup = 0.5,
	Execute = function(standModel, player)
		local char = standModel.Parent
		if char then
			Cream.MadnessSorrow(char)
		end
	end,
}

return AbilityRegistry
