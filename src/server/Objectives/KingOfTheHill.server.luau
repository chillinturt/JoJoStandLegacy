local ControlPointModule = require(game.ServerScriptService.Objectives:WaitForChild("ControlPointModule"))
local KOTHObjectivesFolder = game.Workspace:WaitForChild("Objectives"):WaitForChild("KOTH")
local ThreeTeamsKOTHObjectivesFolder = game.Workspace:WaitForChild("Objectives"):WaitForChild("ThreeTeamKOTH")

-- Default configuration values
local CAPTURE_SPEED = 50
local DECAY_SPEED = 100
local HOLD_TIME_TO_WIN = 180
local CONTROLPOINT_SIZE = Vector3.new(50, 30, 50)

-- Listen for when the control point is complete, wait 5 seconds, then spawn a new one
local function onControlPointComplete(pointData)
	task.wait(5)
	print("Removing old control point...")

	ControlPointModule.RemoveControlPoint(pointData)

	print("Respawning control point...")

	-- Spawn new control point at the same position.
	local newPoint = ControlPointModule.SpawnControlPointThreeTeams(
		pointData.position,
		pointData.size,
		CAPTURE_SPEED,
		DECAY_SPEED,
		HOLD_TIME_TO_WIN,
		pointData.objectivePart
	)

	print("New control point spawned at:", pointData.position)

	-- Start monitoring the new point again
	task.spawn(function()
		while task.wait(0.5) do
			if newPoint.matchOver then
				onControlPointComplete(newPoint)
				break
			end
		end
	end)
end

--previously used version
--[[ For each part in the objectives folder, create a control point
for _, objectivePart in ipairs(KOTHObjectivesFolder:GetChildren()) do
	if objectivePart:IsA("BasePart") then
		local position = objectivePart.Position
		local newPos = position + Vector3.new(0, 15, 0)

		local point = ControlPointModule.SpawnControlPoint(
			newPos,
			CONTROLPOINT_SIZE,
			CAPTURE_SPEED,
			DECAY_SPEED,
			HOLD_TIME_TO_WIN,
			objectivePart
		)

		-- Monitor this control point for completion
		task.spawn(function()
			while task.wait(0.5) do
				if point.matchOver then
					onControlPointComplete(point)
					break
				end
			end
		end)

		print("Spawned control point at:", position)
	end
end
]]

-- For each part in the objectives folder, create a control point
for _, objectivePart in ipairs(ThreeTeamsKOTHObjectivesFolder:GetChildren()) do
	if objectivePart:IsA("BasePart") then
		local position = objectivePart.Position
		local newPos = position + Vector3.new(0, 15, 0)

		local point = ControlPointModule.SpawnControlPointThreeTeams(
			newPos,
			CONTROLPOINT_SIZE,
			CAPTURE_SPEED,
			DECAY_SPEED,
			HOLD_TIME_TO_WIN,
			objectivePart
		)

		-- Monitor this control point for completion
		task.spawn(function()
			while task.wait(0.5) do
				if point.matchOver then
					onControlPointComplete(point)
					break
				end
			end
		end)
	end
end
