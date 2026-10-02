local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- CombatUtils.lua
local GeneralCombat = {}

local AnimationModule = require(game.ServerScriptService.BasicCombat:WaitForChild("AnimationModule"))
local hitboxSpawner = require(game.ServerScriptService.BasicCombat:WaitForChild("HitboxSpawner"))
local standUitls = require(game.ServerScriptService.BasicCombat:WaitForChild("StandUtils"))
local SoundUtils = require(game.ServerScriptService.Utilities:WaitForChild("SoundUtils"))

-- Track combo index per character
local comboIndices = {}
local comboResetTimers = {}
local comboCooldowns = {}
local punchCooldowns = {}

local HITBOX_SIZE = Vector3.new(6, 8, 9)
local PILOT_PUNCH_ANIMATIONS = { "136847469830162", "116981576719265", "115059281874785" }

local STAND_OFF_PUNCH_DAMAGE = 5
local BASE_COMBO = 5

-- Startup: brief delay between the swing starting (animation/sound fire
-- immediately) and the hitbox actually landing, so the bare-handed combo has
-- a touch of real weight instead of connecting the instant you press.
local STAND_OFF_PUNCH_STARTUP = 0.08

function GeneralCombat.StandOffPunch(character, damage)
	local primaryParty = character:FindFirstChild("HumanoidRootPart")
	if not primaryParty or not character then
		return false
	end

	if standUitls.GetActiveStand(character) then
		return
	end

	-- Combo cooldown: prevent starting a new combo too soon
	if comboCooldowns[character] and tick() < comboCooldowns[character] then
		return false -- Still in combo cooldown
	end

	local finalDamage = damage or STAND_OFF_PUNCH_DAMAGE

	-- Check cooldown
	if punchCooldowns[character] and tick() < punchCooldowns[character] then
		return false -- Still on cooldown
	end
	punchCooldowns[character] = tick() + 0.4 -- Set new cooldown

	-- Initialize combo index if needed
	if not comboIndices[character] then
		comboIndices[character] = 1
	end

	local index = comboIndices[character]

	-- Reuse animations for punches past 3
	local animIndex = index
	if index > 3 then
		animIndex = (index % 2 == 0) and 2 or 3
	end

	local hitboxOffset = CFrame.new(0, 0, -3)

	AnimationModule.StopAnimationsOfPriority(character, Enum.AnimationPriority.Action)

	AnimationModule.PlayAnimation(
		character,
		PILOT_PUNCH_ANIMATIONS[animIndex],
		false,
		Enum.AnimationPriority.Action,
		1.5
	)

	-- Advance combo index or finish combo
	if index >= BASE_COMBO then
		comboIndices[character] = 1
		comboCooldowns[character] = tick() + 1 -- cooldown after full combo
	else
		comboIndices[character] = index + 1
	end

	--play sound
	SoundUtils.PlaySound({
		Root = primaryParty,
		soundName = "StandOffPunchEffects",
		soundID = "9113305631",
		volume = 1,
		playbackSpeed = 2,
		looped = false,
	})

	task.delay(STAND_OFF_PUNCH_STARTUP, function()
		if not character.Parent then
			return
		end

		hitboxSpawner.spawnStandOffHitbox({
			Character = character,
			Damage = finalDamage,

			StatScaling = {
				Strength = 0.2,
			},

			Size = HITBOX_SIZE,
			Offset = hitboxOffset,
			Color = BrickColor.new("Bright red"),
			Duration = 0.3,
			StunDuration = 0.2,
			Transparency = 1,
			Name = "BasicPunchHitbox",

			HitSoundId = 4799537772,
			HitSoundPitch = 1,
			HitSoundVolume = 1,
			HitSoundPlaybackSpeed = 1,
			RandomPitchRange = 0.08,
		})
	end)

	--reset index in 3 seconds if index == 1
	-- Reset combo after 3 seconds of inactivity if index == 2 (after punch 1)
	if comboResetTimers[character] then
		task.cancel(comboResetTimers[character])
	end
	comboResetTimers[character] = task.delay(1, function()
		comboIndices[character] = 1
	end)

	return true
end

return GeneralCombat
