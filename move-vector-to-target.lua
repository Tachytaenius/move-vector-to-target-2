-- Search for all TEMP and TODO, check code, etc

-- TODO: Add description of algorithm and what problems it solves

local vec2 = require("lib.mathsies").vec2

local circleDistanceEpsilon = 1e-6 -- If the numbers involved get too big, this will break with floats

local normaliseOrZero = require("normalise-or-zero")
local getShortestAngleDifference = require("get-shortest-angle-difference")
local sign = require("sign")

local function circleRaycast(circleRadius, circlePos, rayStart, rayEnd)
	if rayStart == rayEnd then
		return nil
	end

	local startToEnd = rayEnd - rayStart
	local circleToStart = rayStart - circlePos

	local a = vec2.dot(startToEnd, startToEnd)
	local b = 2 * vec2.dot(circleToStart, startToEnd)
	local c = vec2.dot(circleToStart, circleToStart) - circleRadius ^ 2

	local discriminant = b ^ 2 - 4 * a * c
	if discriminant < 0 then
		return nil
	end

	local discriminantSqrt = math.sqrt(discriminant)
	return
		(-b - discriminantSqrt) / (2 * a),
		(-b + discriminantSqrt) / (2 * a)
end

local function linearMove(current, target, rate, dt)
	local currentToTarget = target - current
	local direction = normaliseOrZero(currentToTarget)
	local distance = #currentToTarget
	local newDistance = math.max(0, distance - rate * dt)
	local newCurrentToTarget = direction * newDistance
	return target - newCurrentToTarget
end

local function onTargetMagnitudeCircle(current, target)
	return math.abs(#target - #current) < circleDistanceEpsilon
end

local function perpendicularClockwise(v)
	return vec2(v.y, -v.x)
end

local function perpendicularAnticlockwise(v)
	return vec2(-v.y, v.x)
end

return function(current, target, rate, dt, magnitudeMatchPrioritisation)
	-- Error checking
	assert(0 <= magnitudeMatchPrioritisation and magnitudeMatchPrioritisation <= 1, "Magnitude match prioritisation must be between 0 and 1 inclusive")
	-- If we have no motion, don't move
	if rate == 0 then
		return vec2.clone(current)
	end
	-- Certain edge cases (TODO: check that these do indeed all break if not handled here)
	if magnitudeMatchPrioritisation == 0 or #current == 0 or #target == 0 then
		return linearMove(current, target, rate, dt)
	end
	-- Default
	magnitudeMatchPrioritisation = magnitudeMatchPrioritisation or 0

	-- First we get the direction to do the initial linear move in

	-- Get angle if magnitudeMatchPrioritisation is 0
	local match0Direction = normaliseOrZero(target - current)
	local match0Angle = vec2.toAngle(match0Direction)

	-- Get angle if magnitudeMatchPrioritisation is 1
	local match1Direction
	assert(#current > 0, "Code could lead to normalising a zero vector")
	if onTargetMagnitudeCircle(current, target) then
		-- Go perpendicular around the circle
		local clockwiseOrAnticlockwise = current.x * target.y - current.y * target.x -- Positive is clockwise
		if clockwiseOrAnticlockwise >= 0 then -- Default to anticlockwise for 0 with >=
			match1Direction = perpendicularAnticlockwise(vec2.normalise(current))
		else
			match1Direction = perpendicularClockwise(vec2.normalise(current))
		end
	else
		-- Go outwards towards target magnitude circle if beneath it, inwards if beyond it
		match1Direction = #current < #target and vec2.normalise(current) or -vec2.normalise(current)
	end
	local match1Angle = vec2.toAngle(match1Direction)

	-- Get direction
	local angleDifference = getShortestAngleDifference(match0Angle, match1Angle)
	local moveAngle = match0Angle + angleDifference * magnitudeMatchPrioritisation -- Angular lerp!
	local moveDirection = vec2.fromAngle(moveAngle)

	-- Now move linearly in that direction until hitting the circle, then move along the arc if applicable
	if not onTargetMagnitudeCircle(current, target) then -- Not on the circle
		-- We won't allow overshooting the circle
		-- TODO: Don't allow overshooting target point either

		local t1, t2 = circleRaycast(#target, vec2(), current, current + moveDirection * rate * dt)

		local intersectionT
		if t1 and t2 then
			if 0 <= t1 and t1 <= 1 then
				intersectionT = t1
			elseif 0 <= t2 and t2 <= 1 then
				intersectionT = t2
			end
		end

		if not intersectionT then
			-- Don't limit traversal
			return current + moveDirection * rate * dt
		end

		-- Cap movement to where current movs to at time of intersection
		local timeOfIntersection = intersectionT / rate
		current = current + moveDirection * rate * timeOfIntersection
		dt = math.max(0, dt - timeOfIntersection) -- One would think timeOfIntersection may not perfectly be <= dt due to precision
	end

	-- Move along the arc (dt and current may have changed)
	local originalCurrentMagnitude = #current
	local originalCurrentAngle = vec2.toAngle(current)
	-- Arc length is angle in radians times radius, rate is arc length, originalCurrentMagnitude is radius, and maxAngleChange is angle
	local maxAngleChange = dt * rate / originalCurrentMagnitude
	local targetAngle = vec2.toAngle(target)
	local angleDifference = getShortestAngleDifference(originalCurrentAngle, targetAngle)
	local reachingTarget, angleMove
	if math.abs(angleDifference) <= maxAngleChange then
		angleMove = angleDifference
		reachingTarget = true
	else
		angleMove = sign(angleDifference) * maxAngleChange
		reachingTarget = false
	end
	local newAngle = originalCurrentAngle + angleMove
	current = vec2.fromAngle(newAngle) * originalCurrentMagnitude
	if not reachingTarget then
		return current
	end

	-- We reached the target angle. Do a linear move with remaining time
	-- If our magnitude is beyond the target magnitude, then we will sink down towards target in a linear move
	-- This will also allow the current and target to be equal if we're close enough
	-- Update dt since we are about to use it again
	dt = math.max(0, dt - angleMove / rate)
	current = linearMove(current, target, rate, dt)
	return current
end
