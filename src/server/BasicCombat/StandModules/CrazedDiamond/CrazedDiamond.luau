-- Crazy Diamond (Josuke Higashikata's stand) -- close-range, super-strength "restoration" stand.
-- Rewritten from scratch: the previous version of this file was a copy-paste of TheWorld's ability kit
-- (knife throws + a full server-wide time-stop), which has nothing to do with Crazy Diamond. The kit below
-- is themed on the stand's actual JoJo canon abilities: repairing/healing wounded people and objects back
-- to how they were, immense punching power, and (per the anime) throwing a "repaired" chunk of debris as a
-- weapon. See CrazedDiamond/AbilityRegistry.luau for how these four functions map to the T/R/Z/X ability
-- slots, and CLAUDE.md's "Movement speed" section before touching anything that would set WalkSpeed here --
-- none of these abilities need to (intentionally: no root/freeze effects on this kit).

local CrazedDiamond = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local HitboxSpawner = require(game.ServerScriptService.BasicCombat:WaitForChild("HitboxSpawner"))
local AnimationModule = require(game.ServerScriptService.BasicCombat:WaitForChild("AnimationModule"))
local CombatUtils = require(game.ServerScriptService.BasicCombat:WaitForChild("CombatUtils"))
local SoundModule = require(game.ServerScriptService.Utilities:WaitForChild("SoundUtils"))
local RaycastModule = require(game.ServerScriptService.BasicCombat:WaitForChild("RaycastModule"))

local SpawnClientVfx = ReplicatedStorage.Shared.Events:WaitForChild("SpawnVfx")

-- Generic "punch swing" animation shared by several stands (see GoldExperiment.luau for the same id).
-- TODO (Studio): every *_ANIM_ID constant below points at this placeholder. Author a unique animation per
-- ability (see the comment next to each constant for what it should look like) and swap the id in.
local PUNCH_ANIM_ID = 90498591949232

--------------------------------------------------------------------
-- Ability 1 - Restoration
-- Crazy Diamond's signature power: touching something wounded or broken resets it to how it was before the
-- damage happened. Used here as a forward "touch" -- an ally caught in it gets healed, an enemy gets hit
-- (repair-force applied to living tissue mid-punch is not gentle). Crazy Diamond also always mends a little
-- of its own user's damage on every cast, matching Josuke self-healing through Kira and Anjuro's fights.
--------------------------------------------------------------------
local RESTORATION_ANIM_ID = PUNCH_ANIM_ID -- TODO (Studio): a gentler "reach out and touch" animation, not a punch

local RESTORATION_ENDLAG = 0.6
local RESTORATION_TOUCH_SIZE = Vector3.new(4, 4, 6)
local RESTORATION_TOUCH_OFFSET = Vector3.new(0, 0, -6)
local RESTORATION_TOUCH_DAMAGE = 16 -- only lands if the touch reaches an enemy instead of an ally
local RESTORATION_TOUCH_HEAL = 32
local RESTORATION_TOUCH_STUN = 1

local RESTORATION_SELF_HEAL = 18
local RESTORATION_SELF_SIZE = Vector3.new(6, 6, 6)

function CrazedDiamond.Restoration(standModel)
	local character = standModel.Parent
	if not character or not standModel.PrimaryPart then
		return false
	end

	AnimationModule.PlayAnimation(standModel, RESTORATION_ANIM_ID, false, Enum.AnimationPriority.Action, 1)
	CombatUtils.SetActionInProgress(character, RESTORATION_ENDLAG)

	SoundModule.PlaySound({
		Root = standModel.PrimaryPart,
		soundName = "RestorationCall",
		-- TODO (Studio): upload + set. Suggest: a soft chime / glass-mending "ting" as Crazy Diamond reaches out
		soundID = "0",
		volume = 2,
		playbackSpeed = 1,
		looped = false,
		range = 160,
	})

	SoundModule.PlaySound({
		Root = standModel.PrimaryPart,
		soundName = "RestorationEffect",
		-- TODO (Studio): upload + set. Suggest: a sparkling healing swell layered with a soft "resetting" crackle
		soundID = "0",
		volume = 2,
		playbackSpeed = 1,
		looped = false,
		range = 160,
	})

	-- Forward touch: heals the first ally it reaches, damages+stuns the first enemy it reaches.
	-- (Team check happens inside HitboxSpawner.spawnHitbox itself -- Heal only applies to teammates.)
	HitboxSpawner.spawnHitbox({
		Character = character,
		Damage = RESTORATION_TOUCH_DAMAGE or 0.1,
		Size = RESTORATION_TOUCH_SIZE,
		Offset = CFrame.new(RESTORATION_TOUCH_OFFSET),
		Color = BrickColor.new("Pink"),
		Duration = 0.4,
		StunDuration = RESTORATION_TOUCH_STUN,
		Transparency = 1,
		Name = "RestorationTouchHitbox",
		Heal = RESTORATION_TOUCH_HEAL,

		HitVFX = {
			-- TODO (Studio): add ReplicatedStorage.Effects.StandEffects.RestorationSpark (Particle-type template)
			-- Small burst of pink/white sparkles plus a faint glowing "seam" -- reads as a wound sealing shut on an
			-- ally, or a rough shove on an enemy. Fine for it to look identical either way.
			effectName = "RestorationSpark",
		},
	})

	-- Crazy Diamond always mends a little of its own user's damage on cast, regardless of what the touch hit.
	HitboxSpawner.spawnStationaryHitbox({
		Position = standModel.PrimaryPart.CFrame,
		Character = character,
		Size = RESTORATION_SELF_SIZE,
		Duration = 0.3,
		Transparency = 1,
		Name = "RestorationSelfHeal",
		Heal = RESTORATION_SELF_HEAL,
		CanSelfHit = true,
	})

	SpawnClientVfx:FireAllClients({
		type = "Stationary",
		effectName = "RestorationSelfPulse",
		-- TODO (Studio): add ReplicatedStorage.Effects.StandEffects.RestorationSelfPulse (Model, PrimaryPart set)
		-- A soft ring of pink/white diamond-sparkle particles that blooms outward from the caster and fades
		-- over roughly half a second.
		cframe = standModel.PrimaryPart.CFrame,
		lifetime = 0.5,
		scale = 0.3,
		expand = true,
		expandRate = 6,
		maxScale = 1,
	})

	return true
end

--------------------------------------------------------------------
-- Ability 2 - Sharpened Disc
-- Crazy Diamond punches a chunk out of the nearest solid surface, "repairs" it mid-air into a razor-edged
-- disc, and hurls it at the target -- the same trick Josuke uses to throw the wall-chunk Crazy Diamond just
-- removed. This is the kit's ranged option; everything else here is melee range.
--------------------------------------------------------------------
local DISC_ANIM_ID = PUNCH_ANIM_ID -- TODO (Studio): a "punch the wall, catch the chunk, throw" wind-up animation

local DISC_HITBOX_SIZE = Vector3.new(5, 1.5, 5)
local DISC_DAMAGE = 26
local DISC_OFFSET = Vector3.new(0, 1, 6)
local DISC_DURATION = 2.5
local DISC_ENDLAG = 0.9
local DISC_STUN = 1.3
local DISC_SPEED = 220

function CrazedDiamond.SharpenedDisc(standModel)
	local character = standModel.Parent
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	AnimationModule.PlayAnimation(standModel, DISC_ANIM_ID, false, Enum.AnimationPriority.Action, 1)
	CombatUtils.SetActionInProgress(character, DISC_ENDLAG)

	SoundModule.PlaySound({
		Root = standModel.PrimaryPart,
		soundName = "SharpenedDiscCall",
		-- TODO (Studio): a quick, heavy "punch through concrete" crunch as Crazy Diamond tears the disc free
		soundID = "0",
		volume = 2,
		playbackSpeed = 1,
		looped = false,
		range = 160,
	})

	SoundModule.PlaySound({
		Root = standModel.PrimaryPart,
		soundName = "SharpenedDiscThrow",
		-- TODO (Studio): a fast spinning whoosh, like a discus/frisbee being hurled hard
		soundID = "0",
		volume = 1.5,
		playbackSpeed = 1,
		looped = false,
		range = 160,
	})

	-- Same aim logic as the rest of the codebase's ranged abilities (see GoldExperiment.EagleStrike).
	local direction
	local startPos = hrp.Position
	local player = Players:GetPlayerFromCharacter(character)

	if player then
		local isClose = RaycastModule.CheckIfTargetIsClose(character, 10)
		if isClose then
			direction = hrp:GetPivot().LookVector
		else
			local targetPoint = RaycastModule.ReturnFacingPoint(character, 1500)
			if not targetPoint then
				warn("No target point found")
				return false
			end
			direction = (targetPoint - startPos).Unit
		end
	else
		direction = hrp:GetPivot().LookVector
	end

	-- Note: spawnProjectile's hit handling lives in ProjectileManager and doesn't support Heal/HitVFX params
	-- (unlike spawnHitbox/spawnStationaryHitbox above) -- matches every other projectile ability in this repo.
	HitboxSpawner.spawnProjectile({
		Stand = standModel,
		Character = character,
		Damage = DISC_DAMAGE,
		Size = DISC_HITBOX_SIZE,
		Offset = DISC_OFFSET,
		Color = BrickColor.new("Medium stone grey"),
		Duration = DISC_DURATION,
		StunDuration = DISC_STUN,
		Transparency = 0.3,
		Name = "SharpenedDiscHitbox",
		Speed = DISC_SPEED,
		Direction = direction,
		Origin = startPos,
	})

	SpawnClientVfx:FireAllClients({
		type = "Projectile",
		effectName = "SharpenedDisc",
		-- TODO (Studio): add ReplicatedStorage.Effects.StandEffects.SharpenedDisc (Model, PrimaryPart set)
		-- A flat stone/concrete disc ~2 studs across with visibly "repaired" jagged edges, spinning fast around
		-- its own axis in flight, trailing a short dust/debris trail. Needs a PrimaryPart so the client can
		-- orient it along its flight path.
		id = HttpService:GenerateGUID(false),
		origin = startPos,
		direction = direction,
		speed = DISC_SPEED,
		lifetime = DISC_DURATION,
	})

	return true
end

--------------------------------------------------------------------
-- Ability 3 - Overdrive Punch ("Dora!!")
-- One devastating full-power straight punch -- Crazy Diamond is at least as physically strong as Star
-- Platinum, so a single clean hit sends the target flying before a follow-up impact finishes them off.
--------------------------------------------------------------------
local OVERDRIVE_ANIM_ID = PUNCH_ANIM_ID -- TODO (Studio): a heavy wind-up haymaker animation

local OVERDRIVE_DAMAGE = 20
local OVERDRIVE_SIZE = Vector3.new(5, 7, 10)
local OVERDRIVE_OFFSET = Vector3.new(0, 0, -8)
local OVERDRIVE_ENDLAG = 1
local OVERDRIVE_STUN = 1.5

local OVERDRIVE_KNOCKBACK_SPEED = 65
local OVERDRIVE_KNOCKBACK_DURATION = 1

local OVERDRIVE_FOLLOWUP_DAMAGE = 15
local OVERDRIVE_FOLLOWUP_SIZE = Vector3.new(20, 20, 20)

function CrazedDiamond.OverdrivePunch(standModel)
	local character = standModel.Parent

	AnimationModule.PlayAnimation(standModel, OVERDRIVE_ANIM_ID, false, Enum.AnimationPriority.Action, 1)
	CombatUtils.SetActionInProgress(character, OVERDRIVE_ENDLAG)

	SoundModule.PlaySound({
		Root = standModel.PrimaryPart,
		soundName = "OverdrivePunchCall",
		-- TODO (Studio): Josuke/Crazy Diamond's "Dora!!" punch shout (the anime's actual barrage callout)
		soundID = "0",
		volume = 2,
		playbackSpeed = 1,
		looped = false,
		range = 160,
	})

	SoundModule.PlaySound({
		Root = standModel.PrimaryPart,
		soundName = "OverdrivePunchEffect",
		-- TODO (Studio): a single heavy, bone-jarring cracking impact -- no fire/heat connotation, this stand
		-- doesn't have an elemental theme
		soundID = "0",
		volume = 2,
		playbackSpeed = 1,
		looped = false,
		range = 160,
	})

	HitboxSpawner.spawnHitbox({
		Character = character,
		Damage = OVERDRIVE_DAMAGE or 0.1,
		Size = OVERDRIVE_SIZE,
		Offset = CFrame.new(OVERDRIVE_OFFSET),
		Color = BrickColor.new("Carnation pink"),
		Duration = 0.75,
		StunDuration = OVERDRIVE_STUN,
		Transparency = 1,
		Name = "OverdrivePunchHitbox",
		CanBlock = false,

		HitVFX = {
			-- TODO (Studio): add ReplicatedStorage.Effects.StandEffects.OverdrivePunchImpact (Particle-type)
			-- Sharp pink/white "diamond shard" burst radiating from the point of impact, plus a quick small
			-- shockwave ring to sell the force of the punch.
			effectName = "OverdrivePunchImpact",
		},

		OnHit = function(targetChar, newDamage)
			local hitHumanoid = targetChar:FindFirstChild("Humanoid")
			local targetRootPart = targetChar:FindFirstChild("HumanoidRootPart")
			local attackerRoot = character:FindFirstChild("HumanoidRootPart")

			if not (hitHumanoid and targetRootPart and attackerRoot) then
				return
			end

			-- Lock rotation
			hitHumanoid.AutoRotate = false

			local rootJoint = targetRootPart:FindFirstChild("RootJoint")
			local originalC0 = rootJoint and rootJoint.C0

			-- Horizontal-only knockback, forward-based (not radial)
			local worldDirection = attackerRoot.CFrame.LookVector
			worldDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z).Unit

			-- Convert WORLD → TARGET LOCAL
			local localDirection = targetRootPart.CFrame:VectorToObjectSpace(worldDirection)

			CombatUtils.ApplyTurningVelocity({
				Character = targetChar,
				Speed = OVERDRIVE_KNOCKBACK_SPEED,
				Duration = OVERDRIVE_KNOCKBACK_DURATION,
				Name = "OverdrivePunchVelocity",
				Direction = localDirection,
			})

			-- Restore rotation, then land the follow-up impact where the target ends up
			task.delay(OVERDRIVE_KNOCKBACK_DURATION, function()
				if hitHumanoid then
					hitHumanoid.AutoRotate = true
				end
				if rootJoint and originalC0 then
					rootJoint.C0 = originalC0
				end

				if not targetRootPart.Parent then
					return
				end

				HitboxSpawner.spawnStationaryHitbox({
					Position = targetRootPart.CFrame,
					Stand = standModel,
					Character = character,
					Damage = OVERDRIVE_FOLLOWUP_DAMAGE,
					Size = OVERDRIVE_FOLLOWUP_SIZE,
					Offset = Vector3.new(0, 0, 0),
					Color = BrickColor.new("Carnation pink"),
					Duration = 1,
					StunDuration = 1,
					Transparency = 0.3,
					Name = "OverdrivePunchFollowupHitbox",
				})

				SpawnClientVfx:FireAllClients({
					type = "Stationary",
					effectName = "OverdrivePunchLanding",
					-- TODO (Studio): add ReplicatedStorage.Effects.StandEffects.OverdrivePunchLanding
					-- Ground-impact shockwave where the target lands: cracked terrain / dust burst with pink
					-- diamond-sparkle motes mixed in.
					cframe = targetRootPart.CFrame,
					lifetime = 0.6,
					scale = 0.3,
					expand = true,
					expandRate = 8,
					maxScale = 1,
				})
			end)
		end,
	})
end

--------------------------------------------------------------------
-- Ability 4 - Perfect Repair (Ultimate)
-- Crazy Diamond unleashes the full force of its restorative power in one instant burst: everyone nearby gets
-- "reset" to how they should be. Allies are healed (with a few lingering aftershock pulses), enemies get
-- caught in the violent snap-back of raw repair energy and take damage instead. Replaces the old copy-pasted
-- TimeStop ability, which belonged to a different stand entirely and isn't part of Crazy Diamond's kit.
--------------------------------------------------------------------
local PERFECTREPAIR_ANIM_ID = PUNCH_ANIM_ID -- TODO (Studio): a big two-fisted "slam the ground" flourish

local PERFECTREPAIR_ENDLAG = 1.2
local PERFECTREPAIR_RADIUS = Vector3.new(48, 48, 48)
local PERFECTREPAIR_DAMAGE = 38
local PERFECTREPAIR_HEAL = 70
local PERFECTREPAIR_STUN = 1.75

local PERFECTREPAIR_AFTERSHOCK_HEAL = 12
local PERFECTREPAIR_AFTERSHOCK_RADIUS = Vector3.new(30, 30, 30)
local PERFECTREPAIR_AFTERSHOCK_PULSES = 3
local PERFECTREPAIR_AFTERSHOCK_DELAY = 1

function CrazedDiamond.PerfectRepair(standModel)
	local character = standModel.Parent
	if not character then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	AnimationModule.PlayAnimation(standModel, PERFECTREPAIR_ANIM_ID, false, Enum.AnimationPriority.Action, 1)
	CombatUtils.SetActionInProgress(character, PERFECTREPAIR_ENDLAG)

	SoundModule.PlaySound({
		Root = hrp,
		soundName = "PerfectRepairCall",
		-- TODO (Studio): a huge magical "resetting" swell -- think glass shards flying back together at speed
		soundID = "0",
		volume = 3,
		playbackSpeed = 1,
		looped = false,
		range = 200,
	})

	SoundModule.PlaySound({
		Root = hrp,
		soundName = "PerfectRepairBurst",
		-- TODO (Studio): a heavy concussive boom to sell the shockwave hitting everyone in range at once
		soundID = "0",
		volume = 3,
		playbackSpeed = 1,
		looped = false,
		range = 200,
	})

	-- One instant AoE pulse: HitboxSpawner's team check does the heal/damage split automatically (same
	-- mechanism as GoldExperiment.LifeOverflow), so this single call heals every ally in range and damages
	-- every enemy in range.
	HitboxSpawner.spawnStationaryHitbox({
		Position = hrp.CFrame,
		Character = character,
		Size = PERFECTREPAIR_RADIUS,
		Duration = 0.5,
		StunDuration = PERFECTREPAIR_STUN,
		Transparency = 1,
		Name = "PerfectRepairBurstHitbox",
		Damage = PERFECTREPAIR_DAMAGE,
		Heal = PERFECTREPAIR_HEAL,
		CanSelfHit = true,
	})

	SpawnClientVfx:FireAllClients({
		type = "Stationary",
		effectName = "PerfectRepairBurst",
		-- TODO (Studio): add ReplicatedStorage.Effects.StandEffects.PerfectRepairBurst (Model, PrimaryPart set)
		-- Large expanding ring/sphere: pink/white "repair" sparkles washing outward, plus a harsher
		-- cracked-glass shockwave ripple layered in. Should read as one big instant "reset" pulse, not a
		-- sustained field -- keep the lifetime short.
		cframe = hrp.CFrame,
		lifetime = 0.6,
		scale = 0.2,
		expand = true,
		expandRate = 10,
		maxScale = 1,
	})

	-- Lingering restorative aftershock: a few smaller follow-up heal pulses for allies who stuck around.
	task.spawn(function()
		for _ = 1, PERFECTREPAIR_AFTERSHOCK_PULSES do
			task.wait(PERFECTREPAIR_AFTERSHOCK_DELAY)

			if not (character.Parent and hrp.Parent) then
				break
			end

			HitboxSpawner.spawnStationaryHitbox({
				Position = hrp.CFrame,
				Character = character,
				Size = PERFECTREPAIR_AFTERSHOCK_RADIUS,
				Duration = 0.3,
				Transparency = 1,
				Name = "PerfectRepairAftershockHeal",
				Heal = PERFECTREPAIR_AFTERSHOCK_HEAL,
				CanSelfHit = true,
			})

			SpawnClientVfx:FireAllClients({
				type = "Stationary",
				effectName = "PerfectRepairAftershock",
				-- TODO (Studio): add ReplicatedStorage.Effects.StandEffects.PerfectRepairAftershock
				-- A small, soft pink/white sparkle ring that blooms and fades quickly -- a gentler echo of the
				-- main burst above.
				cframe = hrp.CFrame,
				lifetime = 0.5,
				scale = 0.3,
				expand = true,
				expandRate = 5,
				maxScale = 1,
			})
		end
	end)

	return true
end

return CrazedDiamond
