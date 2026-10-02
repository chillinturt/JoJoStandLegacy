local BasicStandAttacks = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local IDLE_ANIM_ID = 89452205434139
--local PUNCH_ANIMATIONS = {"93085018014908", "103624770697086", "134941790648824"}  -- Animation IDs
local PUNCH_ANIMATIONS = { "90498591949232", "86291795389163", "88632829279678" } -- Animation IDs
local PILOT_PUNCH_ANIMATIONS = { "136847469830162", "116981576719265", "115059281874785" }

local HITBOX_SIZE = Vector3.new(6, 8, 9)
local BARRAGE_INTERVAL = 0.15
local MAX_BARRAGE_DURATION = 3 -- seconds

local PUNCH_COMBO_COOLDOWN = 1

local BASE_PUNCH_COOLDOWN = 0.4
local DEX_SPEED_PER_POINT = 0.05
local BASE_COMBO = 3

-- Startup: brief delay between the swing starting (animation/sound fire
-- immediately) and the hitbox actually landing, so stand punches have a
-- touch of real weight instead of connecting the instant you press.
local STAND_PUNCH_STARTUP = 0.08
-- Startup before the barrage's hitbox loop actually starts dealing damage --
-- the wind-up into "ORA ORA ORA", not the interval between individual hits.
local BARRAGE_STARTUP = 0.15

local barragingFlags = {}

local StandUtils = require(script.Parent.StandUtils)
local AnimationModule = require(game.ServerScriptService.BasicCombat:WaitForChild("AnimationModule"))
local hitboxSpawner = require(game.ServerScriptService.BasicCombat:WaitForChild("HitboxSpawner"))
local CombatUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))
local PilotModule = require(game.ServerScriptService.BasicCombat:WaitForChild("PilotModule"))
local SoundUtils = require(game.ServerScriptService.Utilities:WaitForChild("SoundUtils"))
local HeroManager = require(game.ServerScriptService.DataSaving.HeroManager)
local TalentsModule = require(game.ServerScriptService.DataSaving.Upgrades:WaitForChild("TalentsModule"))
local QuestManager = require(ServerScriptService.DataSaving.QuestManager)
local OceanService = require(ServerScriptService.OceanService:WaitForChild("OceanService"))

-- Track combo index per stand
local comboIndices = {}
local comboResetTimers = {}
local comboCooldowns = {}
local punchCooldowns = {}

local PUNCH_DAMAGE = {
	["StarPurple"] = 5,
	["HierophantGrand"] = 4,
	["CrazedDiamond"] = 5,
	["KingCarmine"] = 4.5,
	["GoldExperiment"] = 4.5,
	["KaiserQueen"] = 4.5,
	["NuclearRain"] = 4,
	["ThatHand"] = 4.5,
	["HeavensDoor"] = 4.5,
	["WhiteSake"] = 4.5,
	["TuskAct4"] = 5,
	["MagiciansRed"] = 4.5,
	["TheWorld"] = 5,
	["Metallica"] = 4,
	["Cream"] = 4.5,
	["StoneFree"] = 5,
	["HermitPurple"] = 5,
	["StickyFingers"] = 5,
}

local BarrageCallSounds = {
	HierophantGrand = "9057816324",
	ThatHand = "112427142415678",
	StarPurple = "5712021815",
	TheWorld = "127227906993008",
	TuskAct4 = "9057749505",
	CrazedDiamond = "6995124948",
	KaiserQueen = "5522363173",
	StickyFingers = "5785504754",
	StoneFree = "121928424129671",
}

local SpawnClientVfx = ReplicatedStorage.Shared.Events:WaitForChild("SpawnVfx")

local function resetStandRig(standModel)
	local motor = standModel.PrimaryPart:FindFirstChild("StandMotor", true)
	if not motor then
		return
	end

	-- Reset offsets
	motor.Transform = CFrame.identity
	motor.C0 = motor:GetAttribute("DefaultC0") or motor.C0
end

local function IsCharacterStand(heroValue)
	return heroValue == "NuclearRain" or heroValue == "HermitPurple"
end

function BasicStandAttacks.BasicPunch(standModel)
	local character = standModel.Parent
	if not character then
		return false
	end

	local standTag = standModel:FindFirstChild("StandTag")
	if not standTag then
		return false
	end

	local player = Players:GetPlayerFromCharacter(character)
	local powersFolder
	local heroValue
	if player then
		heroValue = HeroManager.GetField(player, "Hero")
		powersFolder = player:FindFirstChild("Powers")
	else
		powersFolder = character:FindFirstChild("Powers")
		heroValue = powersFolder:FindFirstChild("Hero").Value
	end

	local isCharacterStand = IsCharacterStand(heroValue)

	-- ✅ Only require PrimaryPart for NON-character stands
	local primaryPart = standModel.PrimaryPart
	if not isCharacterStand and not primaryPart then
		return false
	end

	if CombatUtils.IsBlocking(character) then
		return
	end

	if CombatUtils.GetStun(character) then
		return
	end

	-- Combo cooldown: prevent starting a new combo too soon
	if comboCooldowns[character] and tick() < comboCooldowns[character] then
		return false -- Still in combo cooldown
	end

	local dexterity = 0
	if player then
		local stats = TalentsModule.GetStats(player)

		if stats and stats.Talents then
			dexterity = stats.Talents.Dexterity or 0
		end
	end

	-- Check cooldown
	if punchCooldowns[standModel] and tick() < punchCooldowns[standModel] then
		return false -- Still on cooldown
	end
	local cooldownMultiplier = 1 - (dexterity * DEX_SPEED_PER_POINT)
	cooldownMultiplier = math.clamp(cooldownMultiplier, 0.3, 1) -- prevent absurd speed

	local punchCooldown = BASE_PUNCH_COOLDOWN * cooldownMultiplier
	punchCooldowns[standModel] = tick() + punchCooldown -- Set new cooldown

	-- Initialize combo index if needed
	if not comboIndices[character] then
		comboIndices[character] = 1
	end
	local index = comboIndices[character]

	local animIndex = index

	if index > 3 then
		animIndex = (index % 2 == 0) and 2 or 3
	end

	if standTag.Value == "TuskAct1" or standTag.Value == "TuskAct2" or standTag.Value == "TuskAct3" then
		if player then
			if heroValue then
				HeroManager.SetField(player, "Hero", "TuskAct4")
				heroValue = HeroManager.GetField(player, "Hero")
			end

			StandUtils.RemoveStand(character)
			standModel = StandUtils.SummonStand(character, "TuskAct4")

			if OceanService:IsSwimming(character) then
				StandUtils.StartSwimmingCorrection(character)
			end

			-- Wait one frame for joints + animator
			task.wait()

			-- Reset rig state completely
			resetStandRig(standModel)

			-- Stop ANY lingering animations
			AnimationModule.StopAllAnimations(standModel)
		end
	end

	local hitboxOffset = CFrame.new(2, 0, -8)
	local rotation = CFrame.Angles(0, 0, 0)
	-- Stop idle and play punch animation
	AnimationModule.StopAllAnimations(standModel)
	if PilotModule.GetBoolPilotMode(character) then
		AnimationModule.PlayAnimation(
			standModel,
			PILOT_PUNCH_ANIMATIONS[animIndex],
			false,
			Enum.AnimationPriority.Action,
			1.5
		)
		hitboxOffset = CFrame.new(0, 0, -3)
	else
		if IsCharacterStand(heroValue) then
			AnimationModule.PlayAnimation(
				character,
				PILOT_PUNCH_ANIMATIONS[animIndex],
				false,
				Enum.AnimationPriority.Action,
				1.5
			)
			-- ✅ Only rotate for specific stands
			if heroValue == "NuclearRain" then
				rotation = CFrame.Angles(0, math.rad(90), 0)
			else
				rotation = CFrame.identity
			end
			if heroValue == "HermitPurple" then
				hitboxOffset = CFrame.new(0, 0, -2)
			else
				hitboxOffset = CFrame.new(2, 0, 0)
			end
		else
			AnimationModule.PlayAnimationThenIdle(
				standModel,
				PUNCH_ANIMATIONS[animIndex],
				false,
				Enum.AnimationPriority.Action,
				1.5
			)
		end
	end

	local maxCombo = BASE_COMBO + dexterity

	-- Advance combo index or finish combo
	if index >= maxCombo then
		comboIndices[character] = 1
		comboCooldowns[character] = tick() + PUNCH_COMBO_COOLDOWN
	else
		comboIndices[character] = index + 1
	end

	-- Prepare for next combo punch
	--comboIndices[character] = index % 3 + 1
	local soundRoot = isCharacterStand and character:FindFirstChild("HumanoidRootPart") or standModel.PrimaryPart

	--play sound
	SoundUtils.PlaySound({
		Root = soundRoot,
		soundName = "PunchEffects",
		soundID = "9113305631",
		volume = 1.25,
		playbackSpeed = 2,
		looped = false,
	})

	task.delay(STAND_PUNCH_STARTUP, function()
		if not standModel.Parent or not character.Parent then
			return
		end

		hitboxSpawner.spawnHitbox({
			Character = character,
			Damage = PUNCH_DAMAGE[standTag.Value] or 0.1,

			StatScaling = {
				Power = 0.2,
			},

			Size = HITBOX_SIZE,
			Offset = hitboxOffset,
			Color = BrickColor.new("Bright red"),
			Duration = 0.1,
			Transparency = 1,
			Name = "BasicPunchHitbox",
			Rotation = rotation,
			StunDuration = 0.2,

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
		--AnimationModule.PlayAnimation(standModel, IDLE_ANIM_ID, true, Enum.AnimationPriority.Action, 1)
	end)

	return true
end

function BasicStandAttacks.StartBarrage(character)
	local standModel = StandUtils.getStandModel(character)

	if not standModel then
		return false
	end

	local player = Players:GetPlayerFromCharacter(character)
	local powersFolder
	local heroValue
	if player then
		heroValue = HeroManager.GetField(player, "Hero")
		powersFolder = player:FindFirstChild("Powers")
	else
		powersFolder = character:FindFirstChild("Powers")
		heroValue = powersFolder:FindFirstChild("Hero").Value
	end

	local isCharacterStand = IsCharacterStand(heroValue)

	-- ✅ Only require PrimaryPart for NON-character stands
	local primaryPart = standModel.PrimaryPart
	if not isCharacterStand and not primaryPart then
		return false
	end

	local motor = nil

	if not isCharacterStand then
		motor = primaryPart:FindFirstChild("StandMotor", true)
	end

	local standTag = standModel:FindFirstChild("StandTag")
	if not standTag then
		return false
	end

	if CombatUtils.IsBlocking(character) then
		return
	end

	local actionFlag = CombatUtils.GetActionInProgress(character)
	if actionFlag then
		return
	end
	CombatUtils.SetActionInProgress(character, MAX_BARRAGE_DURATION)

	if standTag.Value == "TuskAct1" or standTag.Value == "TuskAct2" or standTag.Value == "TuskAct3" then
		if player then
			if heroValue then
				HeroManager.SetField(player, "Hero", "TuskAct4")
				heroValue = HeroManager.GetField(player, "Hero")
			end

			StandUtils.RemoveStand(character)
			standModel = StandUtils.SummonStand(character, "TuskAct4")

			if OceanService:IsSwimming(character) then
				StandUtils.StartSwimmingCorrection(character)
			end

			-- Wait one frame for joints + animator
			task.wait()

			-- Reset rig state completely
			resetStandRig(standModel)

			-- Stop ANY lingering animations
			AnimationModule.StopAllAnimations(standModel)

			motor = standModel.PrimaryPart:WaitForChild("StandMotor", 2)
		end
	end

	-- Cache original motor position
	local defaultC0
	if motor then
		defaultC0 = motor:GetAttribute("DefaultC0") or motor.C0
		motor:SetAttribute("DefaultC0", defaultC0)
	end

	local STAND_BARRAGE_ANIMID = 103626308901658
	local AnimSpeed = 1.5
	local hitBoxOffset = CFrame.new(0, 0, -8)

	-- Shift forward for barrage
	if PilotModule.GetBoolPilotMode(character) then
		STAND_BARRAGE_ANIMID = 127837357946102
		AnimSpeed = 2
		hitBoxOffset = CFrame.new(0, 0, -3)
		-- Keep original orientation, only shift relative position
		--PilotModule.SetPoseOffset(character, CFrame.new(1.5, 0, 0))
	else
		if not isCharacterStand and motor then
			motor.C0 = defaultC0 * CFrame.new(2, 0, 0)
		end
	end

	-- Stop idle and play barrage animation
	AnimationModule.StopAllAnimations(standModel)
	local rotation = CFrame.Angles(0, 0, 0)
	if isCharacterStand then
		STAND_BARRAGE_ANIMID = 127837357946102 -- pilot mode / character barrage
		AnimationModule.PlayAnimation(character, STAND_BARRAGE_ANIMID, false, Enum.AnimationPriority.Action, AnimSpeed)
		rotation = CFrame.Angles(0, math.rad(90), 0)
		hitBoxOffset = CFrame.new(2, 0, 0)
		if heroValue == "HermitPurple" then
			rotation = CFrame.Angles(0, 0, 0)
			hitBoxOffset = CFrame.new(0, 0, -2)
		end
	else
		AnimationModule.PlayAnimation(standModel, STAND_BARRAGE_ANIMID, false, Enum.AnimationPriority.Action, AnimSpeed)
	end

	-- Set barrage flag
	barragingFlags[character] = true

	-- Auto-stop barrage after max duration
	task.delay(MAX_BARRAGE_DURATION, function()
		if barragingFlags[character] then
			BasicStandAttacks.StopBarrage(character)
		end
	end)

	local soundRoot = isCharacterStand and character:FindFirstChild("HumanoidRootPart") or standModel.PrimaryPart

	--play sound
	SoundUtils.PlaySound({
		Root = soundRoot,
		soundName = "BarrageEffects",
		soundID = "129949908820890",
		volume = 2,
		playbackSpeed = 1,
		looped = false,
	})

	--check if the heroValue has a valid barrage call in the table. if so, then play it using the call below:
	--if heroValue is in the table, then:
	local callSoundId = BarrageCallSounds[heroValue]
	if callSoundId then
		SoundUtils.PlaySound({
			Root = soundRoot,
			soundName = "BarrageCall",
			soundID = callSoundId,
			volume = 1,
			playbackSpeed = 1,
			looped = false,
		})
	end

	-- Start spawning hitboxes (after a short wind-up into the flurry)
	task.spawn(function()
		task.wait(BARRAGE_STARTUP)
		while barragingFlags[character] do
			hitboxSpawner.spawnHitbox({
				Character = character,
				Damage = PUNCH_DAMAGE[heroValue] / 4.5,

				StatScaling = {
					Power = 0.05,
				},

				Size = HITBOX_SIZE,
				Offset = hitBoxOffset,
				Color = BrickColor.new("Bright red"),
				Duration = 0.4,
				StunDuration = 0.4,
				Transparency = 1,
				Name = "BarragePunchHitbox",
				Rotation = rotation,
				RemoveOnStun = false,
			})
			task.wait(BARRAGE_INTERVAL)
		end
	end)

	local distance = 15
	local speed = 8
	local rate = 0.05 --delay between punches

	local barrageVfxRoot = standModel
	if isCharacterStand then
		barrageVfxRoot = character
	end

	SpawnClientVfx:FireAllClients({
		type = "Barrage",
		action = "Start",
		character = barrageVfxRoot,
		distance = distance,
		speed = speed,
		rate = rate,
		armCopy = true,
	})

	local conn
	conn = standModel.AncestryChanged:Connect(function(_, parent)
		if not parent then -- stand got removed from workspace
			BasicStandAttacks.StopBarrage(character)
			if conn then
				conn:Disconnect()
			end
		end
	end)

	if QuestManager.HasQuest(player, "StandBarrageTutorial") then
		QuestManager.CompleteQuest(player, "StandBarrageTutorial")
	end

	return true
end

function BasicStandAttacks.StopBarrage(character)
	local standModel = StandUtils.getStandModel(character)

	barragingFlags[character] = false

	local actionFlag = CombatUtils.GetActionInProgress(character)
	if actionFlag then
		CombatUtils.SetActionInProgress(character, 0)
	end
	if not standModel then
		CombatUtils.SetActionInProgress(character, 0)
		return true
	end

	local motor = standModel:FindFirstChild("StandMotor", true)
	if motor and motor:IsA("Motor6D") then
		local defaultC0 = motor:GetAttribute("DefaultC0")
		if defaultC0 then
			motor.C0 = defaultC0
		end
		motor.Transform = CFrame.identity
	end

	-- Clear barrage flag
	barragingFlags[character] = nil

	local player = Players:GetPlayerFromCharacter(character)
	local powersFolder
	local heroValue
	if player then
		heroValue = HeroManager.GetField(player, "Hero")
		powersFolder = player:FindFirstChild("Powers")
	else
		powersFolder = character:FindFirstChild("Powers")
		heroValue = powersFolder:FindFirstChild("Hero")
	end

	-- Reset animation
	if IsCharacterStand(heroValue) then
		AnimationModule.StopAllAnimations(character)
	else
		AnimationModule.StopAllAnimations(standModel)
	end
	AnimationModule.PlayAnimation(standModel, IDLE_ANIM_ID, true, Enum.AnimationPriority.Idle, 1)

	local isCharacterStand = IsCharacterStand(heroValue)
	local barrageVfxRoot = standModel
	if isCharacterStand then
		barrageVfxRoot = character
	end

	local soundRoot = isCharacterStand and character:FindFirstChild("HumanoidRootPart") or standModel.PrimaryPart

	SoundUtils.StopSound(soundRoot, "BarrageCall")
	SoundUtils.StopSound(soundRoot, "BarrageEffects")

	SpawnClientVfx:FireAllClients({
		type = "Barrage",
		action = "End",
		character = barrageVfxRoot,
	})

	return true
end

return BasicStandAttacks
