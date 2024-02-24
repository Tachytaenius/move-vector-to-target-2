local tau = math.pi * 2

return function(a, b)
	-- a to b is b - a
	return (b - a + tau / 2) % tau - tau / 2
end
