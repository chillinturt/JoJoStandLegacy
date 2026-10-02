-- AbilityHandler ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AbilityHandler = {}

-- Modules
local CombatUtils = require(ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))
local HeroManager = require(game.ServerScriptService.DataSaving.HeroManager)
local HamonModule = require(game.ServerScriptService.BasicCombat.SpecailtyScripts.Hamon:WaitForChild("Hamon"))

-- Where all Specialty modules live
local SpecialtyScripts = ServerScriptService.BasicCombat.SpecailtyScripts

-- Cooldowns: cooldowns[player][abilityId] = timestamp
local cooldowns = {}

-- Track active hold abilities: activeHolds[player][abilityId] = true/false
local activeHolds = {}

local function hasEnoughHamon(character, cost)
	if not cost or cost <= 0 then
		return true
	end

	local hamonValue = HamonModule.GetHamon(character)
	if not hamonValue then
		return false
	end

	return hamonValue >= cost
end

-- True if the character is still around and not dead -- used to bail out of
-- an ability's Startup wind-up (see below) if the player died/left/despawned
-- mid-cast instead of firing the ability on an invalid character.
local function isCharacterUsable(character)
	if not character or not character.Parent then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return false
	end
	return true
end

---------------------------------------------------------------------
-- Startup: an optional per-ability wind-up before it actually fires,
-- configured via abilityData.Startup (seconds, defaults to 0/instant) right
-- next to Cooldown in each specialty's AbilityRegistry. Mirrors the same
-- mechanism in the stand AbilityHandler (see its comment for the full
-- rationale and the multi-stage-Execute exceptions) -- keep both in sync.
---------------------------------------------------------------------
local function waitForStartup(character, abilityData)
	local startup = abilityData.Startup or 0
	if startup <= 0 then
		return true
	end

	CombatUtils.SetActionInProgress(character, startup)
	task.wait(startup)

	if not isCharacterUsable(character) then
		return false
	end
	if CombatUtils.GetStun(character) then
		return false
	end
	if not hasEnoughHamon(character, abilityData.HamonCost) then
		return false
	end

	return true
end

---------------------------------------------------------------------
-- Load a Specialty's AbilityRegistry
---------------------------------------------------------------------
local function loadAbilityRegistry(specName)
	local specFolder = SpecialtyScripts:FindFirstChild(specName)
	if not specFolder then
		return nil
	end

	local registryScript = specFolder:FindFirstChild("AbilityRegistry")
	if not registryScript then
		return nil
	end

	return require(registryScript)
end

---------------------------------------------------------------------
-- Send ability types to client
-- SpecialtyRegistry.AbilityTypes should exist
---------------------------------------------------------------------
function AbilityHandler.SendAbilityTypes(player, specName)
	local registry = loadAbilityRegistry(specName)
	if not registry then
		return
	end

	local types = registry.AbilityTypes or {}

	local AbilityTypesRemote = ReplicatedStorage.Shared.BasicCombat:WaitForChild("SpecialtyAbilityTypes")
	AbilityTypesRemote:FireClient(player, types)
end

-- Apply a cooldown for a player+abilityId (seconds)
function AbilityHandler.ApplyCooldown(player, abilityId, duration)
	cooldowns[player] = cooldowns[player] or {}
	cooldowns[player][abilityId] = tick()
	-- fire UI for client
	local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("SpecCooldownUpdateEvent")
	cooldownUIEvent:FireClient(player, abilityId, duration or 0)
end

-- Check if player is currently on cooldown for abilityId. Returns remaining time or 0.
function AbilityHandler.IsOnCooldown(player, abilityId)
	local playerCDs = cooldowns[player]
	if not playerCDs or not playerCDs[abilityId] then
		return 0
	end
	local last = playerCDs[abilityId]
	-- if registry cooldown unknown here, caller can pass the cooldown to compute remaining
	return tick() - last
end

---------------------------------------------------------------------
-- Execute an ability request from client
-- Arguments:
--    abilityId: number
--    state: string or nil ("Start", "Stop", "Toggle", nil)
---------------------------------------------------------------------
function AbilityHandler.ExecuteAbility(player, abilityId, state)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- ❌ Block abilities while dead
	if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
		print("Ability blocked: player is dead")
		return
	end

	if CombatUtils.IsBlocking(character) then
		print("isblocking")
		return
	end

	-- Validate Specialty ownership
	local specValue = HeroManager.GetField(player, "Specialty")
	if not specValue or specValue == "None" then
		return
	end

	-- Load registry
	local registry = loadAbilityRegistry(specValue)
	if not registry then
		return
	end

	local abilityData = registry[abilityId]
	if not abilityData then
		return
	end

	local abilityType = registry.AbilityTypes[abilityId] or "Press"
	local cooldown = abilityData.Cooldown or 0

	-- Setup tracking
	cooldowns[player] = cooldowns[player] or {}
	activeHolds[player] = activeHolds[player] or {}
	local lastUse = cooldowns[player][abilityId]
	local isActive = activeHolds[player][abilityId] == true

	--------------------------------------------------
	-- HOLD ABILITY LOGIC
	--------------------------------------------------
	if abilityType == "Hold" then
		-- STOP cannot run unless ability is active
		if state == "Stop" then
			if not isActive then
				return -- ❗ prevent StopSplash from firing
			end

			-- Execute Stop
			if abilityData.ExecuteStop then
				abilityData.ExecuteStop(player)
			end

			-- Mark inactive
			activeHolds[player][abilityId] = false

			-- Apply cooldown (only now)
			if cooldown > 0 then
				cooldowns[player][abilityId] = tick()
				local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("SpecCooldownUpdateEvent")
				cooldownUIEvent:FireClient(player, abilityId, cooldown)
			end

			return
		end

		-- START logic
		if state == "Start" then
			-- Reject Start if on cooldown
			if lastUse and tick() - lastUse < cooldown then
				return
			end

			-- Action lock & stun (Start only)
			if CombatUtils.GetStun(character) then
				return
			end
			local actionFlag = CombatUtils.GetActionInProgress(character)
			if actionFlag then
				return
			end
			if not hasEnoughHamon(character, abilityData.HamonCost) then
				return
			end

			if not waitForStartup(character, abilityData) then
				return
			end

			-- Execute Start
			if abilityData.ExecuteStart then
				abilityData.ExecuteStart(player)
			end

			-- Mark active
			activeHolds[player][abilityId] = true

			return
		end

		return
	end

	--------------------------------------------------
	-- TOGGLE ABILITY LOGIC
	--------------------------------------------------
	if abilityType == "Toggle" then
		if activeHolds[player][abilityId] then
			if abilityData.ExecuteStop then
				abilityData.ExecuteStop(player)
			end
			activeHolds[player][abilityId] = false
		else
			if lastUse and tick() - lastUse < cooldown then
				return
			end
			if CombatUtils.GetStun(character) then
				return
			end
			if CombatUtils.GetActionInProgress(character) then
				return
			end

			if not waitForStartup(character, abilityData) then
				return
			end

			if abilityData.ExecuteStart then
				abilityData.ExecuteStart(player)
			end
			activeHolds[player][abilityId] = true

			if cooldown > 0 then
				cooldowns[player][abilityId] = tick()
				local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("SpecCooldownUpdateEvent")
				cooldownUIEvent:FireClient(player, abilityId, cooldown)
			end
		end
		return
	end

	--------------------------------------------------
	-- PRESS ABILITY LOGIC
	--------------------------------------------------
	if not abilityData.BypassGlobalCooldown then
		if lastUse and tick() - lastUse < cooldown then
			return
		end
	end
	if CombatUtils.GetStun(character) then
		return
	end
	local actionFlag = CombatUtils.GetActionInProgress(character)
	if actionFlag then
		return
	end
	if not hasEnoughHamon(character, abilityData.HamonCost) then
		return
	end

	cooldowns[player][abilityId] = tick()
	if not abilityData.BypassGlobalCooldown then
		local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("SpecCooldownUpdateEvent")
		cooldownUIEvent:FireClient(player, abilityId, cooldown)
	end

	if not waitForStartup(character, abilityData) then
		return
	end

	if abilityData.Execute then
		abilityData.Execute(player, state)
	end
end

return AbilityHandler
