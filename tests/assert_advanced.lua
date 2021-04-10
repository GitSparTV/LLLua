local isfatal = false

function assert_fatal(bool)
	isfatal = bool
end

function assert(condition, hint, ...)
	if not condition then
		if isfatal then
			error(hint or "assertion failed!", 2)
		else
			local func = debug.getinfo(2, "lS")
			io.write(func.short_src, ":", func.currentline, ": assertion failed!\n")

			return condition, hint, ...
		end
	end

	return condition, hint, ...
end

function assert_cmp(a, b, ...)
	if a ~= b then
		if isfatal then
			local concat = table.concat({...})
			error("assertion failed! \"" .. tostring(a) .. " ~= " .. tostring(b) .. "\"" .. (... and ". " .. concat or "") .. "\n", 2)
		else
			local func = debug.getinfo(2, "lS")
			io.write(func.short_src, ":", func.currentline, ": assertion failed! \"", tostring(a), " ~= ", tostring(b), "\".")
			if ... then io.write(" ", ...) io.write("\n") end
		end
	end
end