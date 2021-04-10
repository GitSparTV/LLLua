package.path = package.path .. ".\\?\\init.lua"

local Lexer = require("lexer")

local f = assert(io.open("../tests/10mb.lua"))

local lex = Lexer.Setup(f:read("*a"))

	function trace(_, line)
		io.write(debug.getinfo(2).short_src .. ":" .. line, "\n")
	end

	-- debug.sethook(trace, "l")

collectgarbage()
collectgarbage()
collectgarbage("stop")
local s = collectgarbage("count")
local S = os.clock()
while lex.tok ~= Lexer.tokens.eof do
	Lexer.Next(lex)
end
local E = os.clock()
local e = collectgarbage("count")
collectgarbage()
collectgarbage()
collectgarbage("restart")

print("Time:", (E - S) * 1000 .. " ms", "GC: ", math.floor((e - s) / 1024 / 0.01) * 0.01 .. " MB")