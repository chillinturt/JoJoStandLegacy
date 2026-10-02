local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoldExperiment = require(script.Parent:WaitForChild("GoldExperiment"))
local CooldownUpdateEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("CooldownUpdateEvent")

local StandUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("StandUtils"))
local CombatUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))

-- ====================================================================
-- EagleStrike custom state
-- ====================================================================
local COOLDOWN_TIME = 10

local lastEagleUse = {} -- player → tick() of launch OR redirect
local eagleFollowup = {} -- player → tick() when redirect expires

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
	[3] = "Press", -- EagleStrike 2-stage
	[4] = "Press",
}

--------------------------------------------------------------------
-- Ability 1 - LifeOverflow
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "LifeOverflow",
	Type = "Press",
	Cooldown = 12,
	Startup = 0.3,
	Execute = function(standModel, player)
		GoldExperiment.LifeOverflow(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - TreeOfLife
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "TreeOfLife",
	Type = "Press",
	Cooldown = 10,
	Startup = 0.25,
	Execute = function(standModel, player)
		local char = standModel.Parent
		if char then
			GoldExperiment.TreeOfLife(char)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 3 - EagleStrike (Launch → Redirect)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "EagleStrike",
	Type = "Press",
	Cooldown = COOLDOWN_TIME,

	-- ⭐ We handle our own cooldown (like MachOra)
	BypassGlobalCooldown = true,
	-- No Startup here on purpose: Execute is a launch/redirect state machine
	-- and the redirect press must stay instant. See AbilityHandler's
	-- waitForStartup comment.

	Execute = function(standModel, player)
		local character = standModel.Parent
		if not character then
			return
		end

		local now = tick()
		local last = lastEagleUse[player] or 0
		local redirectExpiry = eagleFollowup[player] or 0

		-- ===================================================================
		-- 1) REDIRECT — does NOT obey cooldown/stun/action rules
		-- ===================================================================
		if now <= redirectExpiry then
			local success = GoldExperiment.EagleStrike(character)
			if success then
				-- redirect consumed
				eagleFollowup[player] = nil
			end
			return
		end

		-- ===================================================================
		-- 2) LAUNCH — obeys stun & action
		-- ===================================================================
		if CombatUtils.GetStun(character) then
			return
		end
		if CombatUtils.GetActionInProgress(character) then
			return
		end

		-- Check cooldown
		if now - last < COOLDOWN_TIME then
			return
		end

		-- Perform launch
		local success = GoldExperiment.EagleStrike(character)
		if not success then
			return
		end

		-- start cooldown
		lastEagleUse[player] = now
		CooldownUpdateEvent:FireClient(player, 3, COOLDOWN_TIME)

		-- allow redirect for 2 seconds (same as your old implementation)
		eagleFollowup[player] = now + 9.5
	end,
}

--------------------------------------------------------------------
-- Ability 4 - TimeErase
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "CarnivorousTrap",
	Type = "Press",
	Cooldown = 23,
	Startup = 0.35,
	Execute = function(standModel, player)
		local char = standModel.Parent
		if char then
			GoldExperiment.CarnivorousTrap(char)
		end
	end,
}

return AbilityRegistry
