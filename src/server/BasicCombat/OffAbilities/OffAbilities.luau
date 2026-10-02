-- Default bare-handed (stand-off) ability kit. These fire whenever a player
-- has no stand summoned -- independent of hero, stand, race, or specialty --
-- so every ability roots off the character itself instead of a stand model.
local OffAbilities = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local HitboxSpawner = require(ServerScriptService.BasicCombat:WaitForChild("HitboxSpawner"))
local AnimationModule = require(ServerScriptService.BasicCombat:WaitForChild("AnimationModule"))
local CombatUtils = require(ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))
local SoundModule = require(ServerScriptService.Utilities:WaitForChild("SoundUtils"))
local RaycastModule = require(ServerScriptService.BasicCombat:WaitForChild("RaycastModule"))

-- Shared placeholder animation used across the off-stand kit until dedicated
-- animations are authored (same placeholder the on-stand kits use).
local PLACEHOLDER_ANIM_ID = 136847469830162

local SpawnClientVfx = ReplicatedStorage.Shared.Events:WaitForChild("SpawnVfx")

--------------------------------------------------------------------------------
-- Shared helper: resolve the direction the player is aiming, falling back to
-- their facing direction when nothing is targeted.
--------------------------------------------------------------------------------
local function getAimDirection(character, hrp, maxCloseDistance)
	local isClose = RaycastModule.CheckIfTargetIsClose(character, maxCloseDistance or 10)
	if isClose then
		return hrp.CFrame.LookVector
	end

	local targetPoint = RaycastModule.ReturnFacingPoint(character, 1500)
	if not targetPoint then
		return hrp.CFrame.LookVector
	end

	local direction = targetPoint - hrp.Position
	if direction.Magnitude < 0.01 then
		return hrp.CFrame.LookVector
	end

	return direction.Unit
end

------------------------------------------------------------------------------
-- Jab: a quick bare-fisted punch that lunges the user forward into range.
------------------------------------------------------------------------------
local JAB_DAMAGE = 8
local JAB_SIZE = Vector3.new(5, 8, 9)
local JAB_OFFSET = CFrame.new(0, 0, -3)
local JAB_LUNGE_SPEED = 100
local JAB_LUNGE_DURATION = 0.4
local JAB_STUN = 0.8
local JAB_ENDLAG = 0.35

function OffAbilities.Jab(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return false
	end

	CombatUtils.SetActionInProgress(character, JAB_ENDLAG, false)

	AnimationModule.PlayAnimation(character, PLACEHOLDER_ANIM_ID, false, Enum.AnimationPriority.Action, 1.4)

	SoundModule.PlaySound({
		Root = hrp,
		soundName = "OffJabSwing",
		soundID = "3379716733",
		volume = 1.5,
		playbackSpeed = 1.2,
		looped = false,
	})

	CombatUtils.ApplyTurningVelocity({
		Character = character,
		Speed = JAB_LUNGE_SPEED,
		Duration = JAB_LUNGE_DURATION,
		Name = "OffJabLunge",
	})

	local hitbox = HitboxSpawner.spawnStandOffHitbox({
		Character = character,
		Damage = JAB_DAMAGE,
		StatScaling = { Strength = 1.2 },
		Size = JAB_SIZE,
		Offset = JAB_OFFSET,
		Color = BrickColor.new("Institutional white"),
		Duration = 0.8,
		StunDuration = JAB_STUN,
		Transparency = 0.5,
		Name = "OffJabHitbox",
	})

	SpawnClientVfx:FireAllClients({
		type = "Particle",
		effectName = "PunchImpact",
		attachTo = hrp,
		emitCount = 1,
	})

	local vfxId = HttpService:GenerateGUID(false)
	hitbox:SetAttribute("VFX_ID", vfxId)

	SpawnClientVfx:FireAllClients({
		type = "Attached",
		effectName = "MachOra",
		attachId = vfxId,

		initialRotation = Vector3.new(
			0, -- X
			math.rad(90), -- Y
			math.rad(90) -- Z
		),

		offset = CFrame.new(0, 0, 0),
		scale = 1,
		transparency = 0.7,
		attachTo = hitbox,
	})

	return true
end

------------------------------------------------------------------------------
-- Grapple: grab the nearest opponent and unload a flurry of hits at
-- point-blank range. Movement is locked/restored entirely through CombatUtils
-- (ApplyMoveSpeedMultiplier) rather than writing Humanoid.WalkSpeed/JumpPower
-- directly, so speed buffs/debuffs stay centralized.
------------------------------------------------------------------------------
local GRAPPLE_RANGE = 12
local GRAPPLE_HOLD_DISTANCE = 3.5
local GRAPPLE_HIT_COUNT = 5
local GRAPPLE_HIT_INTERVAL = 0.18
local GRAPPLE_HIT_DAMAGE = 5
local GRAPPLE_FINISHER_DAMAGE = 10
local GRAPPLE_FINISHER_STUN = 1.2
local GRAPPLE_FINISHER_KNOCKBACK = 55
local GRAPPLE_ENDLAG = 0.4

function OffAbilities.Grapple(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return false
	end

	local target = CombatUtils.GetNearestTarget(character, GRAPPLE_RANGE, true)
	if not target then
		return false
	end

	local targetHRP = target:FindFirstChild("HumanoidRootPart")
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if not targetHRP or not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end

	local totalDuration = (GRAPPLE_HIT_COUNT * GRAPPLE_HIT_INTERVAL) + 0.5

	humanoid.AutoRotate = false
	targetHumanoid.AutoRotate = false
	CombatUtils.ApplyMoveSpeedMultiplier(character, 0)
	CombatUtils.ApplyMoveSpeedMultiplier(target, 0)

	CombatUtils.SetActionInProgress(character, totalDuration + GRAPPLE_ENDLAG, false)
	CombatUtils.SetInvulnerable(character, totalDuration + 0.3)
	CombatUtils.SetInvulnerable(target, totalDuration + 0.3, character)

	AnimationModule.PlayAnimation(character, PLACEHOLDER_ANIM_ID, true, Enum.AnimationPriority.Action, 1)

	SoundModule.PlaySound({
		Root = hrp,
		soundName = "OffGrappleGrab",
		soundID = "4748348740",
		volume = 2,
		playbackSpeed = 1,
		looped = false,
	})

	-- Pin the target directly in front of the attacker for the duration of the grab.
	local holdConn
	holdConn = RunService.Heartbeat:Connect(function()
		if not hrp.Parent or not targetHRP.Parent then
			if holdConn then
				holdConn:Disconnect()
				holdConn = nil
			end
			return
		end

		local holdPosition = hrp.Position + (hrp.CFrame.LookVector * GRAPPLE_HOLD_DISTANCE)
		targetHRP.CFrame = CFrame.new(holdPosition, holdPosition + hrp.CFrame.LookVector)
		targetHRP.AssemblyLinearVelocity = Vector3.zero
	end)

	local function releaseGrab()
		if holdConn then
			holdConn:Disconnect()
			holdConn = nil
		end

		if humanoid and humanoid.Parent then
			humanoid.AutoRotate = true
			CombatUtils.ApplyMoveSpeedMultiplier(character, 1)
		end

		if targetHumanoid and targetHumanoid.Parent then
			targetHumanoid.AutoRotate = true
			CombatUtils.ApplyMoveSpeedMultiplier(target, 1)
		end
	end

	task.spawn(function()
		for _ = 1, GRAPPLE_HIT_COUNT do
			if not character.Parent or not target.Parent or targetHumanoid.Health <= 0 then
				break
			end

			HitboxSpawner.spawnStandOffHitbox({
				Character = character,
				Damage = GRAPPLE_HIT_DAMAGE,
				Size = Vector3.new(4, 4, 4),
				Offset = CFrame.new(0, 0, -GRAPPLE_HOLD_DISTANCE),
				Color = BrickColor.new("Institutional white"),
				Duration = 0.1,
				StunDuration = 0,
				Transparency = 0.5,
				Name = "OffGrapplePunch",
				CanBlock = false,
			})

			SoundModule.PlaySound({
				Root = targetHRP,
				soundName = "OffGrappleHit",
				soundID = "3378924410",
				volume = 1.5,
				playbackSpeed = 1.1 + (math.random() * 0.2),
				looped = false,
			})

			SpawnClientVfx:FireAllClients({
				type = "Particle",
				effectName = "HowsThatPunch",
				attachTo = targetHRP,
				emitCount = 1,
			})

			task.wait(GRAPPLE_HIT_INTERVAL)
		end

		-- Finisher: a bigger hit that knocks the target away and ends the grab.
		if target.Parent and targetHumanoid.Health > 0 then
			HitboxSpawner.spawnStandOffHitbox({
				Character = character,
				Damage = GRAPPLE_FINISHER_DAMAGE,
				Size = Vector3.new(5, 5, 5),
				Offset = CFrame.new(0, 0, -GRAPPLE_HOLD_DISTANCE),
				Color = BrickColor.new("Really black"),
				Duration = 0.15,
				StunDuration = GRAPPLE_FINISHER_STUN,
				Transparency = 0.5,
				Name = "OffGrappleFinisher",
				CanBlock = false,
			})

			SoundModule.PlaySound({
				Root = targetHRP,
				soundName = "OffGrappleFinisher",
				soundID = "491270608",
				volume = 3,
				playbackSpeed = 0.9,
				looped = false,
			})
		end

		releaseGrab()

		if target.Parent and targetHumanoid.Health > 0 then
			local knockDir = targetHRP.Position - hrp.Position
			knockDir = Vector3.new(knockDir.X, 0.3, knockDir.Z)
			knockDir = knockDir.Magnitude > 0.01 and knockDir.Unit or hrp.CFrame.LookVector

			CombatUtils.ApplyInstantVelocity(targetHRP, knockDir * GRAPPLE_FINISHER_KNOCKBACK)
		end
	end)

	return true
end

------------------------------------------------------------------------------
-- Rush: a short burst dash toward the aimed direction with a brief window of
-- invulnerability -- a gap-closer or panic escape tool.
------------------------------------------------------------------------------
local RUSH_SPEED = 85
local RUSH_DURATION = 0.35
local RUSH_INVULN = 0.5
local RUSH_HOP = 50
local RUSH_ENDLAG = 0.3

function OffAbilities.Rush(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return false
	end

	local worldDirection = getAimDirection(character, hrp, 10)
	worldDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z)
	if worldDirection.Magnitude < 0.01 then
		worldDirection = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	end
	worldDirection = worldDirection.Unit

	-- Convert to local space so ApplyTurningVelocity can drive it.
	local localDirection = hrp.CFrame:VectorToObjectSpace(worldDirection)

	CombatUtils.SetActionInProgress(character, RUSH_ENDLAG, false)
	CombatUtils.SetInvulnerable(character, RUSH_INVULN)
	CombatUtils.SetIsDashing(character, RUSH_DURATION)

	AnimationModule.PlayAnimationThenIdle(character, PLACEHOLDER_ANIM_ID, false, Enum.AnimationPriority.Action, 2)

	SoundModule.PlaySound({
		Root = hrp,
		soundName = "OffRushDash",
		soundID = "4567255304",
		volume = 2,
		playbackSpeed = 1.4,
		looped = false,
	})

	CombatUtils.ApplyTimedVelocity(hrp, RUSH_HOP, RUSH_DURATION, "RushHop", Vector3.new(0, 1, 0))

	CombatUtils.ApplyTurningVelocity({
		Character = character,
		Speed = RUSH_SPEED,
		Duration = RUSH_DURATION,
		Name = "OffRushVelocity",
		Direction = localDirection,
	})

	SpawnClientVfx:FireAllClients({
		type = "Particle",
		effectName = "DarkSpaceVoidBall",
		attachTo = hrp,
		emitCount = 4,
	})

	return true
end

------------------------------------------------------------------------------
-- Flurry: a toggled bare-fisted barrage. Shorter and weaker per-hit than a
-- stand barrage (see ThatHand.LastStand), but throws more hits and stuns on
-- every connect.
------------------------------------------------------------------------------
local flurryFlags = {}
local FLURRY_DURATION = 3
local FLURRY_INTERVAL = 0.18
local FLURRY_DAMAGE = 3
local FLURRY_STUN = 0.35
local FLURRY_SIZE = Vector3.new(4, 4, 5)
local FLURRY_OFFSET = CFrame.new(0, 0, -3)

function OffAbilities.FlurryStart(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return false
	end

	flurryFlags[character] = true

	-- Auto-stop after max duration
	task.delay(FLURRY_DURATION, function()
		if flurryFlags[character] then
			flurryFlags[character] = false
		end
	end)

	SoundModule.PlaySound({
		Root = hrp,
		soundName = "OffFlurryCall",
		soundID = "5375544504",
		volume = 2,
		playbackSpeed = 1.3,
		looped = false,
	})

	task.spawn(function()
		while flurryFlags[character] do
			if not character.Parent or humanoid.Health <= 0 then
				break
			end

			HitboxSpawner.spawnStandOffHitbox({
				Character = character,
				Damage = FLURRY_DAMAGE,
				Size = FLURRY_SIZE,
				Offset = FLURRY_OFFSET,
				Color = BrickColor.new("Institutional white"),
				Duration = 0.12,
				StunDuration = FLURRY_STUN,
				Transparency = 0.5,
				Name = "OffFlurryHitbox",
			})

			SpawnClientVfx:FireAllClients({
				type = "Particle",
				effectName = "PunchImpact",
				attachTo = hrp,
				emitCount = 1,
			})

			AnimationModule.PlayAnimation(character, PLACEHOLDER_ANIM_ID, false, Enum.AnimationPriority.Action, 3)

			task.wait(FLURRY_INTERVAL)
		end
	end)

	return true
end

function OffAbilities.FlurryStop(character)
	flurryFlags[character] = false
	CombatUtils.SetActionInProgress(character, 0.4)
end

return OffAbilities
