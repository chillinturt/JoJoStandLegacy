-- AbilityHandler ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AbilityHandler = {}

-- Modules
local StandUtils = require(ServerScriptService.BasicCombat:WaitForChild("StandUtils"))
local CombatUtils = require(ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))
local HeroManager = require(game.ServerScriptService.DataSaving.HeroManager)
local HeroGroups = require(ServerScriptService.BasicCombat.StandModules.Handlers:WaitForChild("HeroGroups"))
local XPSystem = require(game.ServerScriptService.DataSaving:WaitForChild("XPSystem"))

-- Where all stand modules live
local StandModules = ServerScriptService.BasicCombat.StandModules

-- The off-stand (bare-handed) ability kit is independent of hero/stand/race/
-- specialty -- every player gets the same default set for now.
local DefaultOffAbilityRegistry =
	require(ServerScriptService.BasicCombat.OffAbilities:WaitForChild("OffAbilityRegistry"))

local AbilityUnlocksEvent = Instance.new("RemoteEvent")
AbilityUnlocksEvent.Name = "AbilityUnlocksEvent"
AbilityUnlocksEvent.Parent = ReplicatedStorage.UIs:WaitForChild("RemoteEvents")

local UNLOCK_LEVELS = {
	[1] = 0,
	[2] = 10,
	[3] = 20,
	[4] = 30, -- ultimate
}

-- Cooldowns: cooldowns[player][mode][abilityId] = timestamp
-- mode is "On" (stand summoned) or "Off" (stand toggled off) -- kept separate so an
-- ability bound to the same keybind/abilityId doesn't share a cooldown across the
-- two ability sets.
local cooldowns = {}

-- Track active hold/toggle abilities: activeHolds[player][mode][abilityId] = true/false
local activeHolds = {}

local function ensurePlayerTables(player)
	cooldowns[player] = cooldowns[player] or { On = {}, Off = {} }
	activeHolds[player] = activeHolds[player] or { On = {}, Off = {} }
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
-- next to Cooldown in each stand's AbilityRegistry -- tune per ability for
-- weight (a heavy haymaker can wind up, a barrier/teleport can stay instant).
-- Locks the character via CombatUtils.SetActionInProgress for the duration
-- (same mechanism used for post-ability endlag elsewhere) so the wind-up
-- can't be interrupted by queuing another input, and re-validates the
-- character afterward in case they died/disconnected mid-wind-up.
--
-- NOT applied to abilities whose Execute function is itself a multi-stage
-- state machine where the "same press" can mean an instant follow-up/cancel
-- (e.g. StarPurple's MachOra follow-up, GoldExperiment's EagleStrike
-- redirect, KingCarmine's TimeErase second-press cancel) -- a flat central
-- delay would wrongly slow those follow-up presses too, so those registries
-- intentionally leave Startup unset.
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
	if abilityData.Hyperarmor ~= true and CombatUtils.GetStun(character) then
		return false
	end

	return true
end

local function getHeroGroup(heroName)
	return HeroGroups.GetHeroGroup(heroName) or heroName
end

function AbilityHandler.TryUnlockAbility(player, abilityId)
	-- Already unlocked
	if AbilityHandler.IsAbilityUnlocked(player, abilityId) then
		return false, "AlreadyUnlocked"
	end

	local unlocked = AbilityHandler.GetUnlockedAbilities(player)

	-- Level requirement
	local requiredLevel
	if abilityId == 4 then
		requiredLevel = 30
	else
		requiredLevel = 0
	end

	local playerLevel = XPSystem.GetField(player, "Level") or 0

	if playerLevel < requiredLevel then
		warn("Unlock failed: not high enough level")
		return false, "LevelTooLow"
	end

	-- Ultimate must be last
	if abilityId == 4 then
		if not (unlocked[1] and unlocked[2] and unlocked[3]) then
			warn("Unlock failed: ultimate locked")
			return false, "UltimateLocked"
		end
	end

	-- Optional: Ability points cost
	local points = XPSystem.GetField(player, "AbilityPoints") or 0
	local COST = 1

	if points < COST then
		warn("Unlock failed: not enough points")
		return false, "NoPoints"
	end

	-- Deduct points
	local data = XPSystem.GetField(player, "AbilityPoints")
	XPSystem.SetField(player, "AbilityPoints", data - COST)

	-- Unlock
	unlocked[abilityId] = true
	HeroManager.SetField(player, "UnlockedAbilities", unlocked)

	print("Unlocked ability:", abilityId)

	AbilityUnlocksEvent:FireClient(player, unlocked)

	return true, "Success"
end

---------------------------------------------------------------------
-- Load a stand's AbilityRegistry
---------------------------------------------------------------------
local function loadAbilityRegistry(standName)
	local standFolder = StandModules:FindFirstChild(standName)
	if not standFolder then
		return nil
	end

	local registryScript = standFolder:FindFirstChild("AbilityRegistry")
	if not registryScript then
		return nil
	end

	return require(registryScript)
end

---------------------------------------------------------------------
-- Resolve which off-stand registry a player should use. Currently everyone
-- gets the same default kit; once players can pick/swap off-stand loadouts,
-- branch on that selection here instead of always returning the default.
---------------------------------------------------------------------
local function getOffAbilityRegistry(player)
	return DefaultOffAbilityRegistry
end

---------------------------------------------------------------------
-- Send ability types to client
-- StandRegistry.AbilityTypes should exist
---------------------------------------------------------------------
function AbilityHandler.SendAbilityTypes(player, standName)
	local registry = loadAbilityRegistry(standName)
	if not registry then
		return
	end

	local types = registry.AbilityTypes or {}

	local AbilityTypesRemote = ReplicatedStorage.Shared.BasicCombat:WaitForChild("StandAbilityTypes")
	AbilityTypesRemote:FireClient(player, types)
end

---------------------------------------------------------------------
-- Broadcast the off-stand (bare-handed) ability types to a client. Lives
-- here rather than on StandUtils because resolving the off registry pulls in
-- CombatUtils, and CombatUtils already requires StandUtils -- putting it on
-- StandUtils would create a require cycle between the two.
---------------------------------------------------------------------
function AbilityHandler.SendOffAbilityTypes(player)
	if not player then
		return
	end

	local registry = getOffAbilityRegistry(player)
	if not registry or not registry.AbilityTypes then
		return
	end

	local AbilityTypesRemote = ReplicatedStorage.Shared.BasicCombat:WaitForChild("StandAbilityTypes")
	AbilityTypesRemote:FireClient(player, registry.AbilityTypes)
end

---------------------------------------------------------------------
-- Resolve the ability types for whatever set a player can currently use
-- (on-stand or off-stand). Used by the client to pull its correct starting
-- state on join/respawn, instead of relying solely on a server-pushed event
-- that can race a LocalScript that hasn't connected its listener yet.
---------------------------------------------------------------------
function AbilityHandler.GetCurrentAbilityTypes(player)
	local character = player.Character
	if not character then
		return nil
	end

	local standModel = StandUtils.getStandModel(character)

	if standModel then
		local heroValue = HeroManager.GetField(player, "Hero")
		if not heroValue or heroValue == "None" then
			return nil
		end

		local heroGroup = getHeroGroup(heroValue)
		local standTag = standModel:FindFirstChild("StandTag")
		if not standTag or getHeroGroup(standTag.Value) ~= heroGroup then
			return nil
		end

		local registry = loadAbilityRegistry(heroGroup)
		return registry and registry.AbilityTypes or nil
	end

	local offRegistry = getOffAbilityRegistry(player)
	return offRegistry and offRegistry.AbilityTypes or nil
end

-- Apply a cooldown for a player+abilityId (seconds). Always targets the on-stand
-- ability set -- this is only ever called directly by on-stand ability code
-- (e.g. KingCarmine), never by the off-stand kit.
function AbilityHandler.ApplyCooldown(player, abilityId, duration)
	ensurePlayerTables(player)
	cooldowns[player].On[abilityId] = tick()
	-- fire UI for client
	local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("CooldownUpdateEvent")
	cooldownUIEvent:FireClient(player, abilityId, duration or 0)
end

function AbilityHandler.ResetCooldown(player, abilityId)
	if not cooldowns[player] then
		return
	end

	-- Remove cooldown entry
	cooldowns[player].On[abilityId] = nil

	-- Tell client UI cooldown is finished
	local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("CooldownUpdateEvent")
	cooldownUIEvent:FireClient(player, abilityId, 0)
end

-- Check if player is currently on cooldown for abilityId. Returns remaining time or 0.
function AbilityHandler.IsOnCooldown(player, abilityId)
	local playerCDs = cooldowns[player]
	if not playerCDs or not playerCDs.On[abilityId] then
		return 0
	end
	local last = playerCDs.On[abilityId]
	-- if registry cooldown unknown here, caller can pass the cooldown to compute remaining
	return tick() - last
end

---------------------------------------------------------------------
-- Shared Hold/Toggle/Press dispatch, used for both the on-stand ability set
-- (root = standModel) and the off-stand ability set (root = character).
-- mode ("On"/"Off") keeps cooldowns and hold/toggle state isolated between
-- the two sets so they never bleed into each other on the same abilityId.
---------------------------------------------------------------------
local function runAbility(player, character, mode, registry, abilityData, root, abilityId, state)
	ensurePlayerTables(player)
	local modeCooldowns = cooldowns[player][mode]
	local modeHolds = activeHolds[player][mode]

	local abilityType = registry.AbilityTypes[abilityId] or "Press"
	local cooldown = abilityData.Cooldown or 0

	local lastUse = modeCooldowns[abilityId]
	local isActive = modeHolds[abilityId] == true

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
				abilityData.ExecuteStop(root, player)
			end

			-- Mark inactive
			modeHolds[abilityId] = false

			-- Apply cooldown (only now)
			if cooldown > 0 then
				modeCooldowns[abilityId] = tick()
				local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("CooldownUpdateEvent")
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

			if not waitForStartup(character, abilityData) then
				return
			end

			-- Execute Start
			if abilityData.ExecuteStart then
				abilityData.ExecuteStart(root, player)
			end

			-- Mark active
			modeHolds[abilityId] = true

			return
		end

		return
	end

	--------------------------------------------------
	-- TOGGLE ABILITY LOGIC
	--------------------------------------------------
	if abilityType == "Toggle" then
		if modeHolds[abilityId] then
			if abilityData.ExecuteStop then
				abilityData.ExecuteStop(root, player)
			end
			modeHolds[abilityId] = false
		else
			if lastUse and tick() - lastUse < cooldown then
				return
			end
			if CombatUtils.GetStun(character) then
				return
			end
			if CombatUtils.GetActionInProgress(character) and not abilityData.EndlagCancel then
				return
			end

			if not waitForStartup(character, abilityData) then
				return
			end

			if abilityData.ExecuteStart then
				abilityData.ExecuteStart(root, player)
			end
			modeHolds[abilityId] = true

			if cooldown > 0 then
				modeCooldowns[abilityId] = tick()
				local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("CooldownUpdateEvent")
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
	if abilityData.Hyperarmor ~= true then
		if CombatUtils.GetStun(character) then
			return
		end
	end
	local actionFlag = CombatUtils.GetActionInProgress(character)
	if actionFlag and not abilityData.EndlagCancel then
		return
	end

	modeCooldowns[abilityId] = tick()
	if not abilityData.BypassGlobalCooldown then
		local cooldownUIEvent = ReplicatedStorage.Shared.BasicCombat.UI:WaitForChild("CooldownUpdateEvent")
		cooldownUIEvent:FireClient(player, abilityId, cooldown)
	end

	if not waitForStartup(character, abilityData) then
		return
	end

	if abilityData.Execute then
		abilityData.Execute(root, player, state)
	end
end

---------------------------------------------------------------------
-- Execute an ability request from client
-- Arguments:
--    abilityId: number
--    state: string or nil ("Start", "Stop", "Toggle", nil)
---------------------------------------------------------------------
function AbilityHandler.ExecuteAbility(player, abilityId, state)
	print("execute ability in handler started...")
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

	local standModel = StandUtils.getStandModel(character)

	--------------------------------------------------
	-- STAND ON: normal (unlockable, leveled) ability set -- requires a hero
	-- with a matching stand equipped.
	--------------------------------------------------
	if standModel then
		local heroValue = HeroManager.GetField(player, "Hero")
		if not heroValue or heroValue == "None" then
			return
		end

		-- Normalize hero (TuskActX → Tusk)
		local heroGroup = getHeroGroup(heroValue)

		local standTag = standModel:FindFirstChild("StandTag")
		if not standTag then
			return
		end

		-- Normalize stand tag too
		local standHeroGroup = getHeroGroup(standTag.Value)

		print("HeroValue:", heroValue)
		print("HeroGroup:", heroGroup)
		print("StandTag:", standTag.Value)
		print("StandGroup:", standHeroGroup)

		if standHeroGroup ~= heroGroup then
			print("Ability blocked: stand mismatch")
			return
		end

		local registry = loadAbilityRegistry(heroGroup)
		if not registry then
			return
		end

		local abilityData = registry[abilityId]
		if not abilityData then
			return
		end

		-- ❌ Block if not unlocked
		if not AbilityHandler.IsAbilityUnlocked(player, abilityId) then
			print("Ability blocked: not unlocked")
			return
		end

		runAbility(player, character, "On", registry, abilityData, standModel, abilityId, state)
		return
	end

	--------------------------------------------------
	-- STAND OFF: bare-handed ability set. Independent of hero/stand/race/
	-- specialty and always available (no unlock gate) -- every player has
	-- this kit, even one who hasn't picked a hero yet.
	--------------------------------------------------
	local offRegistry = getOffAbilityRegistry(player)
	if not offRegistry then
		return
	end

	local offAbilityData = offRegistry[abilityId]
	if not offAbilityData then
		return
	end

	runAbility(player, character, "Off", offRegistry, offAbilityData, character, abilityId, state)
end

function AbilityHandler.GetUnlockedAbilities(player)
	return HeroManager.GetField(player, "UnlockedAbilities") or {}
end

function AbilityHandler.IsAbilityUnlocked(player, abilityId)
	local unlocked = AbilityHandler.GetUnlockedAbilities(player)
	return unlocked[abilityId] == true
end

function AbilityHandler.UnlockAbility(player, abilityId)
	local unlocked = AbilityHandler.GetUnlockedAbilities(player)

	-- Prevent unlocking ultimate early
	if abilityId == 4 then
		if not (unlocked[1] and unlocked[2] and unlocked[3]) then
			warn("Cannot unlock ultimate before other abilities")
			return false
		end
	end

	unlocked[abilityId] = true
	HeroManager.SetField(player, "UnlockedAbilities", unlocked)

	return true
end

return AbilityHandler
