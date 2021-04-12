local isfatal = false
local stack = 0

function assert_fatal(bool)
	isfatal = bool
end

function assert_stack(n)
	stack = n
end

function assert(condition, ...)
	local local_stack = stack
	stack = 0

	if not condition then
		if isfatal then
			local concat = table.concat({...})

			error(... and ". " .. concat or "assertion failed!", 2 + local_stack)
		else
			local func = debug.getinfo(2 + local_stack, "lS")
			io.write(func.short_src, ":", func.currentline, ": assertion failed!")

			if ... then
				io.write(" ", ...)
			end

			io.write("\n")

			return condition, ...
		end
	end

	return condition, hint, ...
end

function assert_cmp(a, b, ...)
	local local_stack = stack
	stack = 0

	if a ~= b then
		if isfatal then
			local concat = table.concat({...})

			error("assertion failed! \"" .. tostring(a) .. " ~= " .. tostring(b) .. "\"" .. (... and ". " .. concat or "") .. "\n", 2 + local_stack)
		else
			local func = debug.getinfo(2 + local_stack, "lS")
			io.write(func.short_src, ":", func.currentline, ": assertion failed! \"", tostring(a), " ~= ", tostring(b), "\".")

			if ... then
				io.write(" ", ...)
			end

			io.write("\n")
		end
	end
end