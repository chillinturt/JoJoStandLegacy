local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AnimationModule = require(ServerScriptService.BasicCombat.AnimationModule)
local StandUtils = require(ServerScriptService.BasicCombat.StandUtils)

local SwimmingState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Ocean"):WaitForChild("SwimmingState")

-- Example animation IDs (replace with your own)
local animations = {
	--96767618650505 old run anim
	Forward = "111996277762833",
	Backward = "74432122888392",
	Left = "127264779281230",
	Right = "137936019211555",
	Idle = "104714640622145",
	Fall = "80938111042689", -- ✅ falling anim
	Land = "74308587429244", -- ✅ landing anim
	SwimIdle = "507785072", -- ✅ swimming idle anim
	SwimMove = "507784897", -- ✅ swimming move anim
	StandForward = "103461332131808",
	StandIdle = "89452205434139",
}

-- Track active animations
local activeStates = {}
local lastDirection = {}
local wasMoving = {}
local standStates = {}
local swimmingPlayers = {}
local swimStillSince = {}
local trackedCharacters = {} -- [player] = { character, humanoid }

-- Directional sectors: Forward/Backward win diagonals; a direction is kept until
-- the input leaves its sector by this many extra degrees, so diagonals and small
-- turns don't flicker between two walk anims.
local FORWARD_MAX_ANGLE = 50
local BACKWARD_MIN_ANGLE = 130
local DIRECTION_HYSTERESIS = 15
local SWIM_IDLE_DELAY = 0.1

local directionCenters = {
	Forward = 0,
	Right = 90,
	Backward = 180,
	Left = -90,
}

local function updateStand(player, character, shouldBeForward)
	local stand = StandUtils.GetActiveStand(character)
	if not stand then
		return
	end

	-- 🚨 BLOCK movement if attacking
	local isActing = AnimationModule.IsActionPlaying(character)

	local desiredState = shouldBeForward and "Forward" or "Idle"

	-- ✅ Prevent spam / restarts
	if standStates[player] == desiredState then
		return
	end

	-- Stop previous
	if standStates[player] == "Forward" then
		AnimationModule.StopAnimation(stand, animations["StandForward"])
	elseif standStates[player] == "Idle" then
		AnimationModule.StopAnimation(stand, animations["StandIdle"])
	end

	-- Play new
	if desiredState == "Forward" then
		if not isActing then
			AnimationModule.PlayAnimation(stand, animations["StandForward"], true, Enum.AnimationPriority.Movement, 1)
		end
	else
		if not isActing then
			AnimationModule.PlayAnimation(stand, animations["StandIdle"], true, Enum.AnimationPriority.Movement, 1)
		end
	end

	standStates[player] = desiredState
end

-- FloorMaterial can lag or go stale on the server for client-owned characters
-- (e.g. after the swim → jump → land sequence), so back it up with a short
-- raycast to the ground before deciding the character is falling.
local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
groundRayParams.RespectCanCollide = true

local function isGrounded(character, humanoid, root)
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return true
	end

	local ignore = { character }
	local stand = StandUtils.GetActiveStand(character)
	if stand then
		table.insert(ignore, stand)
	end
	groundRayParams.FilterDescendantsInstances = ignore

	local rayLength = humanoid.HipHeight + root.Size.Y / 2 + 0.75
	return workspace:Raycast(root.Position, Vector3.new(0, -rayLength, 0), groundRayParams) ~= nil
end

-- Decide movement direction relative to character facing
local function getMovementDirection(player, character, humanoid)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return "Idle"
	end

	-- Swimming overrides all physics states. swimmingPlayers is driven by the
	-- SwimmingState remote, not FloorMaterial, so it stays correct even when
	-- ChangeState(Landed) is called by OceanSwimming to reset freefall.
	if swimmingPlayers[player] then
		if humanoid.MoveDirection.Magnitude > 0.1 then
			swimStillSince[player] = nil
			return "SwimMove"
		end
		-- Only commit to SwimIdle after a short stillness window so momentary
		-- MoveDirection drops from physics jitter don't restart the animation.
		swimStillSince[player] = swimStillSince[player] or tick()
		if lastDirection[player] == "SwimMove" and tick() - swimStillSince[player] < SWIM_IDLE_DELAY then
			return "SwimMove"
		end
		return "SwimIdle"
	end
	swimStillSince[player] = nil

	if not isGrounded(character, humanoid, root) then
		return "Fall"
	end

	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then
		return "Idle"
	end

	-- Angle of the input relative to facing: 0 = forward, 90 = right, ±180 = back, -90 = left
	local localDir = root.CFrame:VectorToObjectSpace(moveDir)
	local angle = math.deg(math.atan2(localDir.X, -localDir.Z))

	local current = directionCenters[lastDirection[player]] and lastDirection[player]
	if current then
		local diff = math.abs((angle - directionCenters[current] + 180) % 360 - 180)
		if diff <= 45 + DIRECTION_HYSTERESIS then
			return current
		end
	end

	if math.abs(angle) <= FORWARD_MAX_ANGLE then
		return "Forward"
	elseif math.abs(angle) >= BACKWARD_MIN_ANGLE then
		return "Backward"
	elseif angle > 0 then
		return "Right"
	else
		return "Left"
	end
end

-- Play the correct animation when state changes
local function onStateChanged(player, humanoid, character)
	if not character or not character.Parent then
		return
	end
	local isActing = AnimationModule.IsActionPlaying(character)

	local direction = getMovementDirection(player, character, humanoid)

	-- ✅ ALWAYS track real movement input (even in air)
	wasMoving[player] = humanoid.MoveDirection.Magnitude > 0.1

	local animId = animations[direction]

	-- Detect landing (Fall/Swim → Grounded) ✅ FIRST
	-- Also handle Swim → ground so a stale swim state doesn't skip cleanup.
	-- Exclude Swim as the destination so falling into water skips the land anim.
	local wasAerial = lastDirection[player] == "Fall" or lastDirection[player] == "SwimIdle" or lastDirection[player] == "SwimMove"
	if wasAerial and direction ~= "Fall" and direction ~= "SwimIdle" and direction ~= "SwimMove" then
		-- Stop fall animation
		if activeStates[player] then
			AnimationModule.StopAnimation(character, activeStates[player].animId)
			activeStates[player] = nil
		end

		-- Play landing anim once. The per-frame update loop starts the walk/idle
		-- anim once the land anim (Action priority) stops counting as an action.
		if not isActing then
			AnimationModule.PlayAnimation(character, animations.Land, false, Enum.AnimationPriority.Action, 1.5)
		end

		lastDirection[player] = direction
		return
	end

	-- Handle Swim (overrides Fall — water has no collision mesh so floor is always Air)
	if direction == "SwimIdle" or direction == "SwimMove" then
		local animId = animations[direction]
		if not activeStates[player] or activeStates[player].direction ~= direction then
			if activeStates[player] then
				AnimationModule.StopAnimation(character, activeStates[player].animId)
			end
			-- Movement priority: doesn't pollute actionStates, so landing and
			-- fall transitions are never blocked. Combat actions (Action priority)
			-- will visually override swim animations naturally.
			AnimationModule.PlayAnimation(character, animId, true, Enum.AnimationPriority.Movement, 1)
			activeStates[player] = {
				direction = direction,
				animId = animId,
			}
		end
		updateStand(player, character, wasMoving[player])
		lastDirection[player] = direction
		return
	end

	-- Handle Fall (high priority)
	if direction == "Fall" then
		if not activeStates[player] or activeStates[player].direction ~= "Fall" then
			if activeStates[player] then
				AnimationModule.StopAnimation(character, activeStates[player].animId)
			end
			-- Movement priority for the same reason as Swim: keeps actionStates
			-- clean so the landing animation is never blocked by isActing.
			AnimationModule.PlayAnimation(character, animations.Fall, true, Enum.AnimationPriority.Movement, 1)
			activeStates[player] = {
				direction = "Fall",
				animId = animations.Fall,
			}
		end

		updateStand(player, character, wasMoving[player])

		lastDirection[player] = "Fall"
		return
	end

	-- ALWAYS update stand (fixes stuck animation bug)
	updateStand(player, character, wasMoving[player])

	-- Now we can early return safely for character
	if activeStates[player] and activeStates[player].direction == direction then
		lastDirection[player] = direction
		return
	end

	-- Stop old track if any
	if activeStates[player] and activeStates[player].animId ~= animId then
		AnimationModule.StopAnimation(character, activeStates[player].animId)
		activeStates[player] = nil
	end

	lastDirection[player] = direction

	-- Only record the state once it's actually playing; otherwise the next update
	-- retries, so the walk anim starts as soon as the blocking action ends.
	if isActing then
		return
	end

	AnimationModule.PlayAnimation(character, animId, true, Enum.AnimationPriority.Movement, 1)
	activeStates[player] = {
		direction = direction,
		animId = animId,
	}
end

-- Setup when player spawns
local function onCharacterAdded(player, character)
	activeStates[player] = nil
	lastDirection[player] = nil
	standStates[player] = nil
	swimmingPlayers[player] = nil
	swimStillSince[player] = nil
	trackedCharacters[player] = nil

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and player.Character == character then
		trackedCharacters[player] = { character = character, humanoid = humanoid }
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	activeStates[player] = nil
	lastDirection[player] = nil
	wasMoving[player] = nil
	standStates[player] = nil
	swimmingPlayers[player] = nil
	swimStillSince[player] = nil
	trackedCharacters[player] = nil
end)

-- Re-evaluate every frame instead of only on MoveDirection/FloorMaterial changes:
-- turning (AutoRotate or shiftlock) changes the facing without firing either
-- signal, and remote/replication ordering around swim exits can skip the one
-- FloorMaterial change that would have ended the fall. onStateChanged is a
-- no-op when nothing changed.
RunService.Heartbeat:Connect(function()
	for player, tracked in trackedCharacters do
		if tracked.character.Parent and tracked.humanoid.Health > 0 then
			onStateChanged(player, tracked.humanoid, tracked.character)
		end
	end
end)

-- Mirror the swim state tracked by OceanService so the animation layer knows
-- when to override Fall with Swim (water has no collision, so FloorMaterial
-- is always Air while floating).
SwimmingState.OnServerEvent:Connect(function(player, action)
	if action == "Enter" then
		swimmingPlayers[player] = true
	elseif action == "Exit" then
		swimmingPlayers[player] = nil
	end
end)
