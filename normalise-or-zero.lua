local vec2 = require("lib.mathsies").vec2

return function(v)
	if #v == 0 then
		return vec2.clone(v)
	end
	return vec2.normalise(v)
end
