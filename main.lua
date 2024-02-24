local vec2 = require("lib.mathsies").vec2

local normaliseOrZero = require("normalise-or-zero")
local limitVectorLength = require("limit-vector-length")
local moveVectorToTarget = require("move-vector-to-target")

local maxTargetLength = 250
local targetMoveRate = 100

local target = vec2()
local current = vec2()
local magnitudeMatchPrioritisationMultiplier = 0.5
local currentMoveRate = 50

local function getBaseMagnitudeMatchPrioritisation(current, target, curveShaperDot, curveShaperMagnitudes)
	curveShaperDot = curveShaperDot or 2
	curveShaperMagnitudes = curveShaperMagnitudes or 0.5
	if #current == 0 or #target == 0 then
		return 0
	end

	local currentDirection = vec2.normalise(current)
	local targetDirection = vec2.normalise(target)
	local dot = math.max(-1, math.min(1, vec2.dot(currentDirection, targetDirection))) -- Similarity of direction, clamped for precision reasons
	-- dot being 0 is when current and target being off by 90 degrees, which is the main case in which the prioritisation should be maximised
	local dotFactor = math.min(1, 1 + dot) ^ curveShaperDot

	local magnitudesFactor = math.min(1, #current / #target) ^ curveShaperMagnitudes

	assert(0 <= dotFactor * magnitudesFactor and dotFactor * magnitudesFactor <= 1, dotFactor * magnitudesFactor) -- TEMP
	return dotFactor * magnitudesFactor
end

function love.update(dt)
	if love.keyboard.isDown("c") then
		current = vec2()
	end
	if love.keyboard.isDown("t") then
		target = vec2()
	end

	local targetMove = vec2()
	if love.keyboard.isDown("w") then
		targetMove.y = targetMove.y - 1
	end
	if love.keyboard.isDown("s") then
		targetMove.y = targetMove.y + 1
	end
	if love.keyboard.isDown("a") then
		targetMove.x = targetMove.x - 1
	end
	if love.keyboard.isDown("d") then
		targetMove.x = targetMove.x + 1
	end
	targetMove = normaliseOrZero(targetMove) * targetMoveRate
	target = limitVectorLength(target + targetMove * dt, maxTargetLength)

	current = moveVectorToTarget(
		current, target, currentMoveRate, dt,
		getBaseMagnitudeMatchPrioritisation(current, target) * magnitudeMatchPrioritisationMultiplier
	)
end

function love.draw()
	love.graphics.translate(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)

	love.graphics.circle("line", 0, 0, maxTargetLength)
	love.graphics.circle("line", 0, 0, #target)

	love.graphics.line(0, -maxTargetLength, 0, maxTargetLength)
	love.graphics.line(-maxTargetLength, 0, maxTargetLength, 0)

	love.graphics.setPointSize(8)
	love.graphics.points(target.x, target.y)

	love.graphics.setPointSize(6)
	love.graphics.points(current.x, current.y)

	love.graphics.origin()

	love.graphics.print(
		"Magnitude match prioritisation multiplier: " .. magnitudeMatchPrioritisationMultiplier .. "\n" ..
		"Base magnitude match prioritisation: " .. getBaseMagnitudeMatchPrioritisation(current, target) .. "\n" ..
		"Magnitude match prioritisation: " .. getBaseMagnitudeMatchPrioritisation(current, target) * magnitudeMatchPrioritisationMultiplier .. "\n" ..
		"Distance from current to target: " .. vec2.distance(current, target)
	)
end

function love.mousepressed(x, y, button)
	local newPos = vec2(x - love.graphics.getWidth() / 2, y - love.graphics.getHeight() / 2)
	if button == 1 then
		current = newPos
	elseif button == 2 then
		target = newPos
	end
end
