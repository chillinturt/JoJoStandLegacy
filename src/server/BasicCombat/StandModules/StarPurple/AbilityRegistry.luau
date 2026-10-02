local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StarPurple = require(script.Parent:WaitForChild("StarPurple"))
local CooldownUpdateEvent = ReplicatedStorage:WaitForChild("Shared")
	:WaitForChild("BasicCombat")
	:WaitForChild("UI")
	:WaitForChild("CooldownUpdateEvent")
local StandUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("StandUtils"))
local CombatUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))

-- Track MachOra cooldown & 2-second follow-up window
local lastMachOraUseTime = {} -- player -> tick()
local machOraState = {}
local machOraFollowupExpiry = {}

local COOLDOWN_TIME = 10
local FOLLOWUP_WINDOW = 2
local AbilityRegistry = {}

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
-- Ability 1 - StarFinger (Press)
--------------------------------------------------------------------
AbilityRegistry[1] = {
	Name = "StarFinger",
	Type = "Press",
	Cooldown = 12,
	Startup = 0.2,
	Execute = function(standModel, player)
		StarPurple.StarFinger(standModel)
	end,
}

--------------------------------------------------------------------
-- Ability 2 - MachOra (Press, with MachOra2 follow-up)
--------------------------------------------------------------------
AbilityRegistry[2] = {
	Name = "MachOra",
	Type = "Press",
	Cooldown = COOLDOWN_TIME,
	Hyperarmor = true,
	BypassGlobalCooldown = true,
	-- No Startup here on purpose: Execute is a 2-stage state machine (first
	-- press launches, second press is an instant follow-up) -- a flat
	-- central wind-up would also delay the follow-up press, which must stay
	-- instant. See AbilityHandler's waitForStartup comment.

	Execute = function(standModel, player)
		local character = standModel.Parent
		if not character then
			return
		end

		local now = tick()
		local state = machOraState[player] or "idle"

		----------------------------------------------------------
		-- ❌ GLOBAL LOCKS
		----------------------------------------------------------

		if CombatUtils.GetActionInProgress(character) then
			return
		end

		----------------------------------------------------------
		-- ✅ MACHORA2 (SECOND PRESS)
		----------------------------------------------------------
		if state == "followup" then
			machOraState[player] = "cooldown"
			machOraFollowupExpiry[player] = nil
			lastMachOraUseTime[player] = now

			StarPurple.onMachOra2Requested(character)
			CooldownUpdateEvent:FireClient(player, 2, COOLDOWN_TIME)

			-- Exit cooldown
			task.delay(COOLDOWN_TIME, function()
				if machOraState[player] == "cooldown" then
					machOraState[player] = "idle"
				end
			end)

			return
		end

		----------------------------------------------------------
		-- ❌ BLOCK NON-IDLE STATES
		----------------------------------------------------------
		if state ~= "idle" then
			return
		end

		if CombatUtils.GetStun(character) then
			return
		end

		----------------------------------------------------------
		-- ❌ COOLDOWN CHECK
		----------------------------------------------------------
		local lastUse = lastMachOraUseTime[player] or 0
		if now - lastUse < COOLDOWN_TIME then
			return
		end

		----------------------------------------------------------
		-- ✅ MACHORA1 (FIRST PRESS)
		----------------------------------------------------------
		StarPurple.onMachOraRequested(character)

		machOraState[player] = "followup"
		machOraFollowupExpiry[player] = now + FOLLOWUP_WINDOW

		-- 🔥 AUTO-EXPIRE FOLLOW-UP → COOLDOWN
		task.delay(FOLLOWUP_WINDOW, function()
			if machOraState[player] == "followup" then
				machOraState[player] = "cooldown"
				machOraFollowupExpiry[player] = nil
				lastMachOraUseTime[player] = tick()

				CooldownUpdateEvent:FireClient(player, 2, COOLDOWN_TIME)

				task.delay(COOLDOWN_TIME, function()
					if machOraState[player] == "cooldown" then
						machOraState[player] = "idle"
					end
				end)
			end
		end)
	end,
}

--------------------------------------------------------------------
-- Ability 3 - GroundPound (Press)
--------------------------------------------------------------------
AbilityRegistry[3] = {
	Name = "GroundPound",
	Type = "Press",
	Cooldown = 12,
	Startup = 0.35,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			StarPurple.GroundPound(standModel)
		end
	end,
}

--------------------------------------------------------------------
-- Ability 4 - TimeStop (Press)
--------------------------------------------------------------------
AbilityRegistry[4] = {
	Name = "TimeStop",
	Type = "Press",
	Cooldown = 40,
	Startup = 0.5,
	Execute = function(standModel, player)
		local character = standModel.Parent
		if character then
			StarPurple.TimeStop(character)
		end
	end,
}

Players.PlayerRemoving:Connect(function(player)
	machOraState[player] = nil
	machOraFollowupExpiry[player] = nil
	lastMachOraUseTime[player] = nil
end)

return AbilityRegistry
