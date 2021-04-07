io.stdout:setvbuf("no")
-- local ffi = require("ffi")
jit.opt.start("hotloop=25")
local TK = require("tokens")
local chars = require("chars")
local tokens, tokennames, reservedtokens = TK.tokens, TK.tokennames, TK.reserved
local EOF = -1
local _b = string.byte
local MAX_LENGTH = 0x7fffff00

local LexerMeta = {
	__call = function(self)
		local offset = self.offset

		if offset <= self.size then
			local c = _b(self.buf, offset)
			self.offset = offset + 1
			self.c = c

			return c
		else
			self.c = EOF

			return EOF
		end
	end,
	__tostring = function(self) return string.format("LexState: %p", self) end,
}

LexerMeta.__index = LexerMeta

function LexerMeta:Newline()
	local c = self.c

	if not chars.iseol(c) then
		error("bad usage")
	end

	local new = self()

	if chars.iseol(new) and c ~= new then
		self()
	end

	local linenumber = self.linenumber + 1

	if linenumber >= MAX_LENGTH then
		error("LJ_ERR_XLINES")
	end

	self.linenumber = linenumber
end

do
	local char_0 = _b("0")

	local char_x_lookup = {
		[_b("x")] = true,
		[_b("X")] = true
	}

	local char_dot = _b(".")

	local char_exponent_sign_lookup = {
		[_b("-")] = true,
		[_b("+")] = true,
	}

	local char_e, char_p = _b("e"), _b("p")
	local bitbor = bit.bor

	local function ScanNumber(str)
		-- str = string.lower(str)
		-- local _, ull = string.find(str, "ull", len - 2, true)
		-- local _, llu = string.find(str, "llu", len - 2, true)
		-- if ull == #str or llu == #str then
		-- 	error("ULL")
		-- end
		-- local _, ll = string.find(str, "ll", len - 3, true)
		-- if ll == #str then
		-- 	error("LL")
		-- end
		-- local _, i = string.find(str, "i", len - 4, true)
		-- if i == #str then
		-- 	error("i")
		-- end
		if not tonumber(str) then
			error(str)
		end

		return tonumber(str)
	end

	function LexerMeta:Number()
		local c = self.c

		if not chars.isdigit(c) then
			error("bad usage")
		end

		local xp = char_e

		if c == char_0 and char_x_lookup[self:SaveNext()] then
			xp = char_p
		end

		while chars.isident(self.c) or self.c == char_dot or (char_exponent_sign_lookup[self.c] and bitbor(c, 0x20) == xp) do
			c = self.c
			self:SaveNext()
		end

		local num = ScanNumber(self:ConcatStrBuffer())

		if not num then
			error("LJ_ERR_XNUMBER")
		end
	end
end

local char_lbrace, char_rbrace = _b("["), _b("]")
local char_eq = _b("=")

function LexerMeta:SkipEq()
	local c = self.c

	if c ~= char_lbrace and c ~= char_rbrace then
		error("bad usage")
	end

	local count = 0

	while self() == char_eq and count < 0x20000000 do
		count = count + 1
	end

	return c == self.c and count or (-count - 1)
end

local char_newlines_lookup = {
	[_b("\n")] = true,
	[_b("\r")] = true
}

function LexerMeta:LongString(sep, iscomment)
	local func = iscomment and self.Next or self.SaveNext
	local c = self()

	if char_newlines_lookup[c] then
		self:Newline()
	end

	while true do
		c = self.c

		if c == EOF then
			error(iscomment and "LJ_ERR_XLCOM" or "LJ_ERR_XLSTR")
		elseif c == char_rbrace then
			if self:SkipEq() == sep then
				self()
				break
			end
		elseif char_newlines_lookup[c] then
			if not iscomment then
				self:Save("\n")
			end

			self:Newline()
		else
			func(self)
		end
	end
end

local chars_eol_eof_lookup = {
	[EOF] = true,
	[_b("\n")] = true,
	[_b("\r")] = true,
}

local char_backslash = _b("\\")
local char_lcurbrace, char_rcurbrace = _b("{"), _b("}")

local chars_escapes_lookup = {
	[_b("a")] = _b("\a"),
	[_b("b")] = _b("\b"),
	[_b("f")] = _b("\f"),
	[_b("n")] = _b("\n"),
	[_b("r")] = _b("\r"),
	[_b("t")] = _b("\t"),
	[_b("v")] = _b("\v")
}

local char_x = _b("x")
local char_u = _b("u")
local char_z = _b("z")
local char_0 = _b("0")

local chars_quotesnbackslash_lookup = {
	[_b('"')] = true,
	[_b("'")] = true,
	[_b("\\")] = true,
}

function LexerMeta:String()
	local delim = self.c -- Delimiter is '\'' or '"'. */
	local c = self()

	while c ~= delim do
		-- print("Char: ", c >= 0 and string.char(c))
		if c == EOF then
			error("LJ_ERR_XSTR")
		elseif char_newlines_lookup[c] then
			error("LJ_ERR_XSTR")
		elseif c == char_backslash then
			c = self() -- Skip the '\\'. */

			-- switch
			if chars_escapes_lookup[c] then
				c = chars_escapes_lookup[c]
			elseif c == char_x then
				-- Hexadecimal escape '\xXX'. */
				c = bit.lshift(bit.band(self(), 15), 4)

				if not chars.isdigit(self.c) then
					if not chars.isxdigit(self.c) then
						goto err_xesc
					end

					c = c + bit.lshift(9, 4)
				end

				c = c + bit.band(self(), 15)

				if not chars.isdigit(self.c) then
					if not chars.isxdigit(self.c) then
						goto err_xesc
					end

					c = c + 9
				end
			elseif c == char_u then
				-- Unicode escape '\u{XX...}'. */
				if self() ~= char_lcurbrace then
					goto err_xesc
				end

				self()
				c = 0
				repeat
					c = bit.bor(bit.lshift(c, 4), bit.band(self.c, 15))

					if not chars.isdigit(self.c) then
						if not chars.isxdigit(self.c) then
							goto err_xesc
						end

						c = c + 9
					end

					if c >= 0x110000 then
						goto err_xesc
					end
				until self() == char_rcurbrace -- Out of Unicode range. */

				if c < 0x800 then
					if c < 0x80 then
						goto break_backslash
					end

					self:SaveN(bit.bor(0xc0, bit.rshift(c, 6)))
				else
					if c >= 0x10000 then
						self:SaveN(bit.bor(0xf0, bit.rshift(c, 18)))
						self:SaveN(bit.bor(0x80, bit.band(bit.rshift(c, 12), 0x3f)))
					else
						-- No surrogates. */
						if c >= 0xd800 and c < 0xe000 then
							goto err_xesc
						end

						self:SaveN(bit.bor(0xe0, bit.rshift(c, 12)))
					end

					self:SaveN(bit.bor(0x80, bit.band(bit.rshift(c, 6), 0x3f)))
				end

				c = bit.bor(0x80, bit.band(c, 0x3f))
			elseif c == char_z then
				-- Skip whitespace. */
				c = self()

				while chars.isspace(c) do
					if char_newlines_lookup[c] then
						self:Newline()
						c = self.c
					else
						c = self()
					end
				end

				goto cont
			elseif char_newlines_lookup[c] then
				self:Save("\n")
				self:Newline()
				c = self.c
				goto cont
			elseif chars_quotesnbackslash_lookup[c] then
				goto break_backslash
			elseif c == EOF then
				c = self.c
				goto cont
			else
				if not chars.isdigit(c) then
					goto err_xesc
				end

				c = c - char_0 -- Decimal escape '\ddd'. */

				if chars.isdigit(self()) then
					c = c * 10 + (self.c - char_0)

					if chars.isdigit(self()) then
						c = c * 10 + (self.c - char_0)

						if c > 255 then
							goto err_xesc
						end

						self()
					end
				end

				self:SaveN(c)
				c = self.c
				goto cont
			end

			-- backslash second char if
			::break_backslash::
			self:SaveN(c)
			c = self()
		else -- BACKSLASH
			c = self:SaveNext()
		end

		-- if
		::cont::
	end

	-- while
	self() -- Skip trailing delimiter. */

	-- print("Buffer: ", self:ConcatStrBuffer())
	do
		return
	end

	::err_xesc::
	error("LJ_ERR_XESC")
end

local char_spaces_lookup = {
	[_b(" ")] = true,
	[_b("\t")] = true,
	[_b("\v")] = true,
	[_b("\f")] = true
}

local chars_quote_lookup = {
	[_b("'")] = true,
	[_b('"')] = true,
}

local char_minus = _b("-")
local char_less = _b("<")
local char_greater = _b(">")
local char_tilde = _b("~")
local char_colon = _b(":")
local char_dot = _b(".")

local chars_single_tokens_lookup = {
	[_b("<")] = tokens.less,
	[_b(">")] = tokens.greater,
	[_b("+")] = tokens.plus,
	[_b("-")] = tokens.minus,
	[_b("/")] = tokens.div,
	[_b("*")] = tokens.mul,
	[_b("%")] = tokens.modulo,
	[_b("^")] = tokens.pow,
	[_b("(")] = tokens.lparen,
	[_b(")")] = tokens.rparen,
	[_b("#")] = tokens.len,
	[_b(",")] = tokens.comma,
	[_b(";")] = tokens.terminator,
	[_b("{")] = tokens.lcurbrace,
	[_b("}")] = tokens.rcurbrace,
	[_b("[")] = tokens.lbrace,
	[_b("]")] = tokens.rbrace,
}

function LexerMeta:Scan()
	self:ResetStrBuffer()

	while true do
		local c = self.c

		-- io.write("Char: ", c, "\n")
		if chars.isident(c) then
			if chars.isdigit(c) then
				self:Number()

				return tokens.number
			end

			repeat
				c = self:SaveNext()
			until not chars.isident(c)
			local str = self:ConcatStrBuffer()
			local isreserved = reservedtokens[str]
			if isreserved then return isreserved end

			return tokens.name
		elseif char_newlines_lookup[c] then
			self:Newline()
		elseif char_spaces_lookup[c] then
			self()
		elseif c == char_minus then
			if self() ~= char_minus then return tokens.minus end

			if self() == char_lbrace then
				local sep = self:SkipEq()
				self:ResetStrBuffer()

				if sep >= 0 then
					self:LongString(sep, true)
					self:ResetStrBuffer()
					goto cont
				end
			end

			while not chars_eol_eof_lookup[c] do
				c = self()
			end

			::cont::
		elseif c == char_lbrace then
			local sep = self:SkipEq()

			if sep >= 0 then
				self:LongString(sep)

				return tokens.string
			elseif sep == -1 then
				return tokens.lbrace
			else
				error("LJ_ERR_XLDELIM")
			end
		elseif c == char_eq then
			if self() ~= char_eq then
				return tokens.assign
			else
				self()

				return tokens.eq
			end
		elseif c == char_less then
			self()

			if self() ~= char_eq then
				return tokens.less
			else
				self()

				return tokens.le
			end
		elseif c == char_greater then
			if self() ~= char_eq then
				return tokens.greater
			else
				self()

				return tokens.ge
			end
		elseif c == char_greater then
			if self() ~= char_eq then
				return tokens.greater
			else
				self()

				return tokens.ge
			end
		elseif c == char_tilde then
			if self() ~= char_eq then
				error("unexpected symbol '~'")
			else
				self()

				return tokens.ne
			end
		elseif c == char_colon then
			if self() ~= char_colon then
				return tokens.method
			else
				self()

				return tokens.label
			end
		elseif chars_quote_lookup[c] then
			self:String()

			return tokens.string
		elseif c == char_dot then
			if self:SaveNext() == char_dot then
				if self() == char_dot then
					self()

					return tokens.dots
				else
					return tokens.concat
				end
			elseif not chars.isdigit(self.c) then
				return tokens.dot
			else
				self:Number()

				return tokens.number
			end
		elseif c == EOF then
			return tokens.eof
		else
			self()
			local token = chars_single_tokens_lookup[c]

			if not token then
				error("Char ", c, string.char(c), "doesn't have a token")
			end

			return token
		end
	end
end

LexerMeta.Next = LexerMeta.__call

function LexerMeta:Lookahead()
	if self.lookahead ~= tokens.eof then
		error("double lookahead")
	end

	self.lookahead = self:Scan()

	return self.lookahead
end

function LexerMeta:SaveN(char)
	local size = self.strbufsize
	self.strbuf[size] = string.char(char)
	self.strbufsize = size + 1
end

function LexerMeta:Save(char)
	local size = self.strbufsize
	self.strbuf[size] = char
	self.strbufsize = size + 1
end

local stringchar = string.char

function LexerMeta:SaveNext()
	if self.c < 0 or self.c > 255 then
		error("LexState.c is out of range (" .. self.c .. ")")
	end

	self:Save(stringchar(self.c))

	return self()
end

function LexerMeta:ResetStrBuffer()
	self.strbufsize = 0
end

local tableconcat = table.concat

function LexerMeta:ConcatStrBuffer()
	local res = tableconcat(self.strbuf, nil, 0, self.strbufsize - 1)
	self.strbufresult = res

	return res
end

local function LexerNext(self)
	self.lastline = self.linenumber
	local lookahead = self.lookahead

	if lookahead == tokens.eof then
		self.tok = self:Scan()
	else
		self.tok = lookahead
		self.lookahead = tokens.eof
	end

	-- print(tokennames[self.tok], self.linenumber)
end

local function LexerSetup(buffer)
	local lex = setmetatable({
		buf = buffer,
		size = #buffer,
		offset = 1,
		c = 0,
		linenumber = 1,
		columnnumber = 0,
		lastline = 0,
		strbuf = {},
		strbufsize = 0,
		strbufresult = "",
		tok = tokens.eof,
		lookahead = tokens.eof,
	}, LexerMeta)

	lex()

	return lex
end

local f = io.open("E:/Spar/LLLua/test.lua")
local lex = LexerSetup(f:read("*a"))

while lex.c ~= EOF do
	LexerNext(lex)
end