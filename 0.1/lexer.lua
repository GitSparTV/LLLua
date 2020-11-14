io.stdout:setvbuf("no")
local ffi = require("ffi")
local util = require("util")
local UNICODE_ACCEPT = 0
local UNICODE_REJECT = 12

local UnicodeCodes = ffi.new("const uint8_t[364]", {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 8, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 3, 11, 6, 6, 6, 5, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 12, 24, 36, 60, 96, 84, 12, 12, 12, 48, 72, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 0, 12, 12, 12, 12, 12, 0, 12, 0, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 24, 12, 12, 12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12, 12, 36, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12, 12, 36, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,})

local function ReadUnicode(state, codep, byte)
	local ctype = UnicodeCodes[byte]

	if (state ~= UNICODE_ACCEPT) then
		codep = bit.bor(bit.band(byte, 0x3f), bit.lshift(codep, 6))
	else
		codep = bit.band(bit.rshift(0xff, ctype), byte)
	end

	state = UnicodeCodes[256 + state + ctype]

	return state, codep
end

local Unicodebuf = ffi.new("unsigned char [8]")

local function PrintUnicode(point)
	if point < 0 then return "Invalid character" end
	if point < 0x80 then return string.char(point) end
	local n = 1
	local mfb = 0x3f
	repeat
		Unicodebuf[8 - n] = bit.bor(0x80, bit.band(point, 0x3f))
		n = n + 1
		point = bit.rshift(point, 6)
		mfb = bit.rshift(mfb, 1)
	until point <= mfb
	Unicodebuf[8 - n] = bit.bor(bit.lshift(bit.bnot(mfb), 1), point)

	return ffi.string(Unicodebuf + (8 - n), n)
end

local TKN_EOF, TKN_OP, TKN_NUMBER, TKN_VAR, TKN_TEXT, TKN_CHAR, TKN_COMMA = -1, 0, 1, 2, 3, 4, 5

local printable = ffi.new("uint8_t[255]", {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0;
	0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0;
	1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0;
	0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1;
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
	0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
	0, 0, 0, 0, 0, 0
})

local TOKENS = {
	[TKN_EOF] = "TKN_EOF",
	[TKN_OP] = "TKN_OP",
	[TKN_NUMBER] = "TKN_NUMBER",
	[TKN_VAR] = "TKN_VAR",
	[TKN_TEXT] = "TKN_TEXT",
	[TKN_CHAR] = "TKN_CHAR",
	[TKN_COMMA] = "TKN_COMMA",
}

local function CheckNext2(char, one, two)
	return char == one or char == two
end

local function CheckPrintable(char)
	if char < 256 then
		return printable[char] == 1
	else
		return true
	end
end

local function ReadNumber(lex)
	local s, first = lex.p, lex.current
	local hexexpo = false
	local cur = lex:Next()

	if first == 48 and CheckNext2(cur, 120, 88) then
		cur = lex:Next()
		hexexpo = true
	end

	local prev = cur

	while true do
		if (cur >= 48 and cur <= 57) or (cur >= 65 and cur <= 70) or (cur >= 97 and cur <= 102) or cur == 46 or CheckNext2(cur, hexexpo and 80 or 69, hexexpo and 112 or 101) or (CheckNext2(prev, hexexpo and 80 or 69, hexexpo and 112 or 101) and CheckNext2(cur, 45, 43)) then
			prev = cur
			cur = lex:Next()
		elseif printable[cur] == 1 then
			error("Unexpected character (" .. PrintUnicode(cur) .. ") after numeral (" .. ffi.string(s, lex.p - s) .. ")")
		else
			break
		end
	end

	local result = ffi.string(s, lex.p - s)
	local num = tonumber(result)

	if num == nil then
		error("Malformed numeral (" .. result .. ")")
	end

	return num
end

local function ReadVar(lex)
	local s = lex.p
	local cur = lex:Next()

	while true do
		if cur > 255 or printable[cur] == 1 then
			cur = lex:Next()
		else
			break
		end
	end

	return ffi.string(s, lex.p - s)
end

local function ReadEscape(lex, quote)
	local next = lex:NextASCII()

	if next == 97 then
		return 7
	elseif next == 98 then
		return 8
	elseif next == 102 then
		return 12
	elseif next == 110 then
		return 10
	elseif next == 114 then
		return 13
	elseif next == 116 then
		return 9
	elseif next == 118 then
		return 11
	elseif next == 92 then
		return 92
	elseif next == 120 then
		next = lex:NextASCII()
		local char = bit.lshift(bit.band(next, 15), 4)

		if next < 48 or next > 57 then
			if (next < 97 and next > 102) and (next < 65 or next > 70) then
				error("Invalid hexadecimal escape sequence")
			end

			char = char + bit.lshift(9, 4)
		end

		next = lex:NextASCII()
		char = char + bit.band(next, 15)

		if next < 48 or next > 57 then
			if (next < 97 and next > 102) and (next < 65 or next > 70) then
				error("Invalid hexadecimal escape sequence")
			end

			char = char + 9
		end

		return char
	elseif next == 117 then
		if lex:NextASCII() ~= 123 then
			error("Invalid Unicode escape sequence. Opening bracket is missing.")
		end

		next = lex:NextASCII()
		local char, str = 0, ""
		repeat
			char = bit.bor(bit.lshift(char, 4), bit.band(next, 15))

			if next < 48 or next > 57 then
				if (next < 97 and next > 102) and (next < 65 or next > 70) then
					error("Invalid Unicode escape sequence. Invalid hexadecimal.")
				end

				char = char + 9
			end

			if char >= 0x110000 then
				error("Invalid Unicode escape sequence. Out of Unicode range.")
			end

			next = lex:NextASCII()
		until next == 125

		if char < 0x800 then
			if char < 0x80 then return char end
			str = str .. string.char(bit.bor(0xc0, bit.rshift(char, 6)))
		else
			if char >= 0x10000 then
				str = str .. string.char(bit.bor(0xf0, bit.rshift(char, 18)))
				str = str .. string.char(bit.bor(0x80, bit.band(bit.rshift(char, 12), 0x3f)))
			else
				if char >= 0xd800 and char < 0xe000 then
					error("Invalid Unicode escape sequence. No surrogates.")
				end

				str = str .. string.char(bit.bor(0xe0, bit.rshift(char, 12)))
			end

			str = str .. string.char(bit.bor(0x80, bit.band(bit.rshift(char, 6), 0x3f)))
		end

		str = str .. string.char(bit.bor(0x80, bit.band(char, 0x3f)))

		return str
	elseif next == 122 then
		lex:NextASCII()

		while lex.current >= 9 and lex.current <= 13 or lex.current == 32 do
			if lex.current == 10 or lex.current == 13 then
				lex:IncLine()
			else
				lex:NextASCII()
			end
		end

		return lex.current
	elseif next == 10 or next == 13 then
		lex:IncLine()

		return 10, true
	elseif next == quote then
		return quote
	elseif next >= 48 and next <= 57 then
		local char = next - 48
		next = lex:NextASCII()

		if next >= 48 and next <= 57 then
			char = char * 10 + (next - 48)
			next = lex:NextASCII()

			if next >= 48 and next <= 57 then
				char = char * 10 + (next - 48)

				if (char > 255) then
					error("Invalid decimal escape sequence. Character is higher than 255.")
				end

				next = lex:NextASCII()
			end
		end

		return char, true
	else
		error("Unknown escape sequence (\\" .. string.char(next) .. ")")
	end
end

local function ReadString(lex)
	local buf = util.Buffer(1, "uint8_t*")
	local p = buf:GetBuffer()
	local base = p
	-- local s, l = {}, 0
	local cur = lex:NextASCII()

	while cur ~= 34 do
		if cur == 92 then
			local char, usecur = ReadEscape(lex, 34)

			if char ~= nil then
				if type(char) == "string" then
					if #char > 1 then
						p, base = buf:Resize(p, #char)
					end

					ffi.copy(p, char, #char)
					p = p + #char
				else
					p, base = buf:Resize(p, 1)
					p[0] = char
					p = p + 1
				end
			end

			cur = usecur and lex.current or lex:NextASCII()
			-- l = l + 1
		elseif cur == 10 or cur == 13 or cur == -1 then
			buf:Free()
			error("Unfinished string literal")
		else
			-- print("insert", cur, PrintUnicode(cur), p - base)
			p, base = buf:Resize(p, 1)
			p[0] = cur
			assert(cur < 256)
			p = p + 1
			-- l = l + 1
			-- s[l] = PrintUnicode(cur) 
			cur = lex:NextASCII()
		end
	end
	-- return table.concat(s)

	return p == base and "" or ffi.string(base, p - base)
end

local lex_meta = {}
lex_meta.__index = lex_meta

function lex_meta:Start()
	self.p = self.source
	local state, char = UNICODE_ACCEPT, 0

	while state ~= UNICODE_REJECT and self.p - self.source <= self.size do
		state, char = ReadUnicode(state, char, self.p[0])

		if state == UNICODE_ACCEPT then
			self.current = char

			return
		end

		self.p = self.p + 1
	end

	self.current = -1
	self.p = self.p + 1

	return -1
end

function lex_meta:Next()
	local state, char = UNICODE_ACCEPT, 0

	while state ~= UNICODE_REJECT and self.p - self.source < self.size do
		self.p = self.p + 1
		state, char = ReadUnicode(state, char, self.p[0])

		if state == UNICODE_ACCEPT then
			self.current = char

			return char
		end
	end

	self.current = -1
	self.p = self.p + 1

	return -1
end

function lex_meta:NextASCII()
	if self.p - self.source > self.size then
		self.current = -1

		return -1
	end

	self.p = self.p + 1
	local char = self.p[0]
	self.current = char

	return char
end

function lex_meta:IncLine()
	local cur = self.current
	local next = self:Next()

	if (next == 10 or next == 13) and cur ~= next then
		self:Next()
	end

	self.curline = self.curline + 1

	if self.curline >= 0x7fffff00 then
		error("Too many lines")
	end
end

local newlex = ffi.metatype([[struct {
	const uint8_t* source;
	const uint8_t* p;
	int32_t current;
	uint32_t curline;
	size_t size;
}]], lex_meta)

function Lexer(script)
	local lex = newlex(script, nil, 0, 1, #script - 1)
	lex:Start()
	local tokens, tokenslen = {}, 0

	while lex.current ~= -1 do
		local char = lex.current
		-- print("Char: ", PrintUnicode(char), "Line: ", lex.curline)

		if char == 10 or char == 13 then
			lex:IncLine()
		elseif char == 32 or char == 11 or char == 12 or char == 9 then
			lex:Next()
		elseif char == 45 then
			local next = lex:Next()

			if next == 45 then
				local cur = lex:Next()

				while cur ~= 10 and cur ~= 13 and cur ~= -1 do
					cur = lex:Next()
				end
			elseif char >= 48 and char <= 57 then
				tokens[tokenslen] = {TKN_NUMBER, ReadNumber(lex), lex.curline}

				tokenslen = tokenslen + 1
				lex:Next()
			else
				tokens[tokenslen] = {TKN_OP, 45, lex.curline}

				tokenslen = tokenslen + 1
				lex:Next()
			end
		elseif char >= 48 and char <= 57 or char == 46 then
			tokens[tokenslen] = {TKN_NUMBER, ReadNumber(lex), lex.curline}

			tokenslen = tokenslen + 1
			-- lex:Next()
		elseif char > 255 or printable[char] == 1 then
			tokens[tokenslen] = {TKN_VAR, ReadVar(lex), lex.curline}

			tokenslen = tokenslen + 1
		elseif char == 34 then
			tokens[tokenslen] = {TKN_TEXT, ReadString(lex), lex.curline}

			tokenslen = tokenslen + 1
			lex:Next()
		elseif char == 39 then
			local symbol, closing = lex:Next()

			if symbol == 92 then
				local char, usecur = ReadEscape(lex, 39)
				symbol = char
				closing = usecur and lex.current or lex:Next()
			elseif symbol == 39 then
				error("Empty char literal")
			end

			if not closing then
				closing = lex:Next()
			end

			if closing ~= 39 then
				error("Char is not closed by \'")
			end

			tokens[tokenslen] = {TKN_CHAR, symbol, lex.curline}

			tokenslen = tokenslen + 1
			lex:Next()
		elseif char == 44 then
			tokens[tokenslen] = {TKN_COMMA,nil, lex.curline}

			tokenslen = tokenslen + 1
			lex:Next()
		else
			error("Unexpected character (" .. PrintUnicode(char) .. ")")
		end
	end

	tokens[tokenslen] = {TKN_EOF,lex.curline}
	tokenslen = tokenslen + 1
	-- for i = 0, tokenslen - 1 do
	-- 	local token = tokens[i]
	-- 	print("Token:", TOKENS[token[1]], token[2] and "Value: <" .. token[2] .. ">" or "")
	-- end

	return tokens, tokenslen
end

return Lexer