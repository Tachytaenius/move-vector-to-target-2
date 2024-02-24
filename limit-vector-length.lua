local vec2 = require("lib.mathsies").vec2

local normaliseOrZero = require("normalise-or-zero")

return function(v, l)
	if #v > l then
		return normaliseOrZero(v) * l
	end
	return vec2.clone(v)
end
