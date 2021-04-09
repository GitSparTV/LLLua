local cntrl = 0x01 -- Control characters
local space = 0x02 -- Space characters
local punct = 0x04 -- Punctuation
local digit = 0x08 -- Digit
local xdigit = 0x10 -- Hexadecimal numbers
local upper = 0x20 -- Uppercase characters
local lower = 0x40 -- Lowercase characters
local ident = 0x80 -- Identifier
local alpha = bit.bor(lower, upper) -- Alphabet
local alnum = bit.bor(alpha, digit) -- Alphabet + numbers
local graph = bit.bor(alnum, punct) -- Graphical characters

local char_bits = {
    [0] = 0, -- -1 (EOF)
	cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl + space, cntrl + space, cntrl + space, cntrl + space, cntrl + space, cntrl, cntrl; -- 0 (NUL) .. 15
	cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl; -- 16 .. 31
	space, punct, punct, punct, punct, punct, punct, punct, punct, punct, punct, punct, punct, punct, punct, punct; -- 32 ( ) .. 47 (/)
	digit + xdigit + ident, digit + xdigit + ident, digit + xdigit + ident, digit + xdigit + ident, digit + xdigit + ident, digit + xdigit + ident, digit + xdigit + ident, digit + xdigit + ident, digit + xdigit + ident, digit + xdigit + ident, punct, punct, punct, punct, punct, punct; -- 48 (0) .. 63 (?)
	punct, xdigit + upper + ident, xdigit + upper + ident, xdigit + upper + ident, xdigit + upper + ident, xdigit + upper + ident, xdigit + upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident; -- 64 (@) .. 79 (O)
	upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, upper + ident, punct, punct, punct, punct, punct + ident; -- 80 ("P") .. 95 ("_")
	punct, xdigit + lower + ident, xdigit + lower + ident, xdigit + lower + ident, xdigit + lower + ident, xdigit + lower + ident, xdigit + lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident; -- 96 (`) .. 111 (o)
	lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, lower + ident, punct, punct, punct, punct, cntrl; -- 112 (p) .. 127 (DEL)
	ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident; -- 128 .. 143
	ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident; -- 144 .. 159
	ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident; -- 160 .. 175
	ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident; -- 176 .. 191
	ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident; -- 192 .. 207
	ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident; -- 208 .. 223
	ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident; -- 224 .. 239
	ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident, ident; -- 240 .. 255
}

local bitband = bit.band

local function isa(c, t)
	return bitband(char_bits[c + 1], t) ~= 0
end

local function MakeMap(mask)
	local map = {}

	for i = 0, #char_bits - 1 do
		if isa(i, mask) then
			map[i] = true
		end
	end

	return map
end

local iscntrl = MakeMap(cntrl)

local isspace = MakeMap(space)

local ispunct = MakeMap(punct)

local isdigit = MakeMap(digit)

local isxdigit = MakeMap(xdigit)

local isupper = MakeMap(upper)

local islower = MakeMap(lower)

local isident = MakeMap(ident)

local isalpha = MakeMap(alpha)

local isalnum = MakeMap(alnum)

local isgraph = MakeMap(graph)

local iseol = {
	[string.byte("\n")] = true,
	[string.byte("\r")] = true,
}

local bitrshift = bit.rshift

local function toupper(c)
	return c - bitrshift(bitband(char_bits[c + 1], lower), 1)
end

local function tolower(c)
	return c + bitband(char_bits[c + 1], upper)
end

return {
	cntrl = cntrl,
	space = space,
	punct = punct,
	digit = digit,
	xdigit = xdigit,
	upper = upper,
	lower = lower,
	ident = ident,
	alpha = alpha,
	alnum = alnum,
	graph = graph,
	isa = isa,
	iscntrl = iscntrl,
	isspace = isspace,
	ispunct = ispunct,
	isdigit = isdigit,
	isxdigit = isxdigit,
	isupper = isupper,
	islower = islower,
	isident = isident,
	isalpha = isalpha,
	isalnum = isalnum,
	isgraph = isgraph,
	iseol = iseol,
	toupper = toupper,
	tolower = tolower,
}