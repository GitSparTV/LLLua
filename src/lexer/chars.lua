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
    [-1] = 0, -- -1 (EOF)
	[0] = cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl, cntrl + space, cntrl + space, cntrl + space, cntrl + space, cntrl + space, cntrl, cntrl; -- 0 (NUL) .. 15
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
	return bitband(char_bits[c], t) ~= 0
end

local function iscntrl(c)
	return isa(c, cntrl)
end

local function isspace(c)
	return isa(c, space)
end

local function ispunct(c)
	return isa(c, punct)
end

local function isdigit(c)
	return isa(c, digit)
end

local function isxdigit(c)
	return isa(c, xdigit)
end

local function isupper(c)
	return isa(c, upper)
end

local function islower(c)
	return isa(c, lower)
end

local function isident(c)
	return isa(c, ident)
end

local function isalpha(c)
	return isa(c, alpha)
end

local function isalnum(c)
	return isa(c, alnum)
end

local function isgraph(c)
	return isa(c, graph)
end

local chars_eol_lookup = {
	[string.byte("\n")] = true,
	[string.byte("\r")] = true,
}

local function iseol(c)
	return chars_eol_lookup[c]
end

local bitrshift = bit.rshift

local function toupper(c)
	return c - bitrshift(islower(c), 1)
end

local function tolower(c)
	return c + isupper(c)
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