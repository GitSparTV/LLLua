local Lexer = require("lexer")
local BC = require("bc_luajit")
local Chunk, Proto = BC[1], BC[2]
local util = require("util")
local f = io.open("new.lllua", "r")
local script = f:read("*a")
f:close()
local TKN_EOF, TKN_OP, TKN_NUMBER, TKN_VAR, TKN_TEXT, TKN_CHAR, TKN_COMMA = -1, 0, 1, 2, 3, 4, 5

local TOKENS = {
	[TKN_EOF] = "TKN_EOF",
	[TKN_OP] = "TKN_OP",
	[TKN_NUMBER] = "TKN_NUMBER",
	[TKN_VAR] = "TKN_VAR",
	[TKN_TEXT] = "TKN_TEXT",
	[TKN_CHAR] = "TKN_CHAR",
	[TKN_COMMA] = "TKN_COMMA",
}

local tokens, tokenslen = Lexer(script)
local nexttoken = util.ArrayIterator(tokens)
local c = Chunk()
local p = Proto(c)
c.protos[0], c.protoslen = p, 1
c.flags = 0x08

local function ReadInstruction(iter, inst)
	local instt = {util.GetOpcode(inst[2])}

	p.lineinfo = p.lineinfo .. string.char(inst[3])
	p.insts[p.sizebc], p.sizebc = instt, p.sizebc + 1
	local next = iter()

	if next[1] == TKN_NUMBER or next[1] == TKN_CHAR then
		instt[2] = next[2]
	else
		error("Operand A expected after instruction opcode \"" .. tostring(inst[2]) .. "\" on line " .. next[3])
	end

	next = iter()

	if next[1] ~= TKN_COMMA then
		error("Comma expected after operand A on line " .. next[3])
	end

	next = iter()

	if next[1] == TKN_NUMBER or next[1] == TKN_CHAR then
		instt[3] = next[2]
	else
		error("Operand B or D expected on line " .. next[3])
	end

	next = iter()

	if next[1] ~= TKN_COMMA then
		local val = instt[3]
		instt[3], instt[4], instt[5] = bit.rshift(val, 8), bit.band(val, 0xFF), val

		return
	end

	next = iter()

	if next[1] == TKN_NUMBER or next[1] == TKN_CHAR then
		instt[4] = next[2]
		instt[5] = bit.lshift(next[2], 8) + instt[3]
	else
		error("Operand C expected on line " .. next[3])
	end

	iter()
end

nexttoken()
print("Reading the script...")

while nexttoken[2] < tokenslen do
	local token = nexttoken:Current()

	if token[1] == TKN_VAR then
		if util.GetOpcode(token[2]) then
			ReadInstruction(nexttoken, token)
		else
			error("Unexpected variable \"" .. tostring(token[2]) .. "\" on line " .. token[3])
		end
	else
		error("Unexpected " .. TOKENS[token[1]] .. " on line " .. token[3])
	end
end

print("Compiling proto...")

do
	local insts = p.insts
	local max = 0

	for i = 0, p.sizebc - 1 do
		local slot = insts[i][2]

		if slot > max then
			max = slot
		end
	end

	print("Framesize: ", max + 1)
	p.framesize = max + 1
end

do
	local lineinfo = p.lineinfo
	local firstline, maxline

	for char = 1, #lineinfo do
		local num = string.byte(lineinfo, char, char)

		if not firstline then
			firstline, maxline = num, num
		end

		if maxline < num then
			maxline = num
		end
	end

	p.firstline, p.numline = firstline, maxline - firstline
	print("Firstline: ", firstline, "\nNumlines: ", maxline - firstline)
end

print("Compiling chunk...")
p.varinfo = "a\0\2\3"
local bc = c:WriteToBC()

do
	print("Validating...")
	local s, err = load(bc)

	if not s then
		error("Verification failed. " .. tostring(err))
	end
end

do
	print("Compiled successfully. " .. #bc .. " bytes")
	local f = io.open("new.llluac", "wb")
	f:write(bc)
	f:close()
end

-- print(load(bc)())

-- local bc = string.dump(function() local a a() end)
-- local ch = Chunk()
-- ch:ReadFromBC(bc)

-- for k,v in pairs(ch.protos[0]) do print(k,v) end