-- io.stdout:setvbuf("full")
-- local ffi = require("ffi")
local TK = require("lexer.tokens")
local chars = require("lexer.chars")
local tokens, reservedtokens = TK.tokens, TK.reserved
local EOF = -1
local _b = string.byte
local MAX_LENGTH = 0x7fffff00

local LexerMeta = {
	__call = function(self)
		local offset = self.offset

		if offset <= self.size then
			self.offset = offset + 1
			self.columnnumber = self.columnnumber + 1
			local c = _b(self.buf, offset)
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
LexerMeta.Next = LexerMeta.__call

function LexerMeta:Error(text)
	local begin, end_ = self.offset - 2, self.offset - 1

	while true do
		if begin <= 0 then break end
		local char = self.buf:sub(begin, begin)
		if char == "\n" or char == "\r" then break end
		begin = begin - 1
	end

	while true do
		if end_ >= self.size then break end
		local char = self.buf:sub(end_, end_)
		if char == "\n" or char == "\r" then break end
		end_ = end_ + 1
	end

	local region = self.buf:sub(begin + 1, end_)
	error("Lexer Error: " .. text .. "\nLine: " .. self.linenumber .. ". Column: " .. (self.columnnumber - 1) .. ". Char: " .. self.c .. ((self.c >= 1 and self.c <= 255) and (" (" .. string.char(self.c) .. ")") or "") .. "\n" .. region .. "\n" .. string.rep(" ", self.offset - begin - 2) .. "^\n")
end

function LexerMeta:Newline()
	do
		local old = self.c

		if not chars.iseol[old] then
			self:Error("bad usage")
		end

		do
			local c = self()

			if chars.iseol[c] and c ~= old then
				self()
			end
		end
	end

	do
		local linenumber = self.linenumber + 1

		if linenumber >= MAX_LENGTH then
			self:Error("LJ_ERR_XLINES")
		end

		self.linenumber = linenumber
	end

	self.columnnumber = 1
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

	function LexerMeta:Number()
		local c = self.c

		if not chars.isdigit[c] then
			self:Error("bad usage")
		end

		local xp = char_e

		if c == char_0 and char_x_lookup[self:SaveNext()] then
			xp = char_p
		end

		while chars.isident[self.c] or self.c == char_dot or (char_exponent_sign_lookup[self.c] and bitbor(c, 0x20) == xp) do
			c = self.c
			self:SaveNext()
		end

		--Do this in parser
		-- if not num then
			-- self:Error("LJ_ERR_XNUMBER")
		-- end
	end
end

local char_lbrace, char_rbrace = _b("["), _b("]")
local char_eq = _b("=")

do
	function LexerMeta:SkipEq()
		local s = self.c

		if not (s == char_lbrace or s == char_rbrace) then
			self:Error("bad usage")
		end

		local count = 0

		while self:SaveNext() == char_eq and count < 0x20000000 do
			count = count + 1
		end

		return self.c == s and count or -count - 1
	end

	function LexerMeta:LongString(sep)
		self()

		if chars.iseol[self.c] then
			self:Newline()
		end

		while true do
			local c = self.c

			if c == EOF then
				self:Error("LJ_ERR_XLSTR")
			elseif c == char_rbrace then
				if self:SkipEq() == sep then
					self.strbufsize = self.strbufsize - sep - 1
					self()

					return
				end
			elseif chars.iseol[c] then
				self:Save("\n")
				self:Newline()
			else
				self:SaveNext()
			end
		end
	end
end

-- We use separate function for comment to eliminate branches in LongString()
do
	function LexerMeta:SkipEqComment()
		local s = self.c

		if not (s == char_lbrace or s == char_rbrace) then
			self:Error("bad usage")
		end

		local count = 0

		while self() == char_eq and count < 0x20000000 do
			count = count + 1
		end

		return self.c == s and count or -count - 1
	end

	function LexerMeta:LongComment(sep)
		self()

		while true do
			local c = self.c

			if c == EOF then
				self:Error("LJ_ERR_XLCOM")
			elseif c == char_rbrace then
				if self:SkipEqComment() == sep then
					self()

					return
				end
			elseif chars.iseol[c] then
				self:Newline()
			else
				self()
			end
		end
	end
end

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
	local delim = self.c
	local c = self()

	while c ~= delim do
		if c == EOF then
			self:Error("LJ_ERR_XSTR")
		elseif chars.iseol[c] then
			self:Error("LJ_ERR_XSTR")
		elseif c == char_backslash then
			c = self()

			if chars_escapes_lookup[c] then
				c = chars_escapes_lookup[c]
			elseif c == char_x then
				c = bit.lshift(bit.band(self(), 15), 4)

				if not chars.isdigit[self.c] then
					if not chars.isxdigit[self.c] then
						goto err_xesc
					end

					c = c + bit.lshift(9, 4)
				end

				c = c + bit.band(self(), 15)

				if not chars.isdigit[self.c] then
					if not chars.isxdigit[self.c] then
						goto err_xesc
					end

					c = c + 9
				end
			elseif c == char_u then
				if self() ~= char_lcurbrace then
					goto err_xesc
				end

				self()
				c = 0
				repeat
					c = bit.bor(bit.lshift(c, 4), bit.band(self.c, 15))

					if not chars.isdigit[self.c] then
						if not chars.isxdigit[self.c] then
							goto err_xesc
						end

						c = c + 9
					end

					if c >= 0x110000 then
						goto err_xesc
					end
				until self() == char_rcurbrace

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
						if c >= 0xd800 and c < 0xe000 then
							goto err_xesc
						end

						self:SaveN(bit.bor(0xe0, bit.rshift(c, 12)))
					end

					self:SaveN(bit.bor(0x80, bit.band(bit.rshift(c, 6), 0x3f)))
				end

				c = bit.bor(0x80, bit.band(c, 0x3f))
			elseif c == char_z then
				c = self()

				while chars.isspace[c] do
					if chars.iseol[c] then
						self:Newline()
						c = self.c
					else
						c = self()
					end
				end

				goto cont
			elseif chars.iseol[c] then
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
				if not chars.isdigit[c] then
					goto err_xesc
				end

				c = c - char_0

				if chars.isdigit[self()] then
					c = c * 10 + (self.c - char_0)

					if chars.isdigit[self()] then
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

			::break_backslash::
			self:SaveN(c)
			c = self()
		else
			c = self:SaveNext()
		end

		::cont::
	end

	self()

	do
		return
	end

	::err_xesc::
	self:Error("LJ_ERR_XESC")
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
	[_b("+")] = tokens.plus,
	[_b("*")] = tokens.mul,
	[_b("/")] = tokens.div,
	[_b("%")] = tokens.mod,
	[_b("^")] = tokens.pow,
	[_b("]")] = tokens.rbrace,
	[_b("{")] = tokens.lcurbrace,
	[_b("}")] = tokens.rcurbrace,
	[_b("(")] = tokens.lparen,
	[_b(")")] = tokens.rparen;
	[_b(",")] = tokens.comma,
	[_b(";")] = tokens.semicolon,
	[_b("#")] = tokens.len;
}

function LexerMeta:Scan()
	self:ResetStrBuffer() -- this should be done in parser on getting the string

	while true do
		local c = self.c

		-- io.write("Char: ", c, "\n")
		if chars.isident[c] then
			if chars.isdigit[c] then
				self:Number()

				return tokens.number
			end

			repeat
				c = self:SaveNext()
			until not chars.isident[c]
			local str = self:ConcatStrBuffer()
			local isreserved = reservedtokens[str]
			if isreserved then return isreserved end

			return tokens.name
		elseif chars.iseol[c] then
			self:Newline()
		elseif char_spaces_lookup[c] then
			self()
		elseif c == char_minus then
			if self() ~= char_minus then return tokens.minus end

			if self() == char_lbrace then
				local sep = self:SkipEq()

				if sep >= 0 then
					self:LongComment(sep)
					goto cont
				end
			end

			while not chars.iseol[self.c] and self.c ~= EOF do
				self()
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
				self:Error("LJ_ERR_XLDELIM")
			end
		elseif c == char_eq then
			if self() ~= char_eq then
				return tokens.assign
			else
				self()

				return tokens.eq
			end
		elseif c == char_less then
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
		elseif c == char_tilde then
			if self() ~= char_eq then
				return tokens.tilde
			else
				self()

				return tokens.ne
			end
		elseif c == char_colon then
			if self() ~= char_colon then
				return tokens.colon
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
			elseif not chars.isdigit[self.c] then
				return tokens.dot
			else
				self:Number()

				return tokens.number
			end
		elseif c == EOF then
			return tokens.eof
		else
			self()

			return chars_single_tokens_lookup[c]
		end
	end
end

function LexerMeta:Lookahead()
	if self.lookahead ~= tokens.eof then
		self:Error("double lookahead")
	end

	local lookahead = self:Scan()
	if not lookahead then
		self:Error("token is nil")
	end
	self.lookahead = lookahead

	return lookahead
end

local stringchar = string.char

function LexerMeta:SaveN(char)
	if char < 0 or char > 255 then
		self:Error("char is out of range (" .. char .. ")")
	end

	local size = self.strbufsize
	self.strbuf[size] = stringchar(char)
	self.strbufsize = size + 1
end

function LexerMeta:Save(char)
	local size = self.strbufsize
	self.strbuf[size] = char
	self.strbufsize = size + 1
end

function LexerMeta:SaveNext()
	if self.c < 0 or self.c > 255 then
		self:Error("lex.c is out of range (" .. self.c .. ")")
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
		local tok = self:Scan()

		if not tok then
			self:Error("token is nil")
		end
		self.tok = tok
	else
		self.tok = lookahead
		self.lookahead = tokens.eof
	end
end

local function LexerSetup(buffer)
	local lex = setmetatable({
		buf = buffer,
		size = #buffer,
		offset = 1,
		c = -1,
		linenumber = 1,
		columnnumber = 0,
		lastline = 1,
		strbuf = {},
		strbufsize = 0,
		strbufresult = "",
		tok = -1,
		lookahead = tokens.eof,
	}, LexerMeta)

	-- Preallocating string buffer to fulfill almost all needs
	do
		for i = 0, 64 do
			lex.strbuf[i] = false
		end
	end

	lex()

	return lex
end

return {
	Setup = LexerSetup,
	Next = LexerNext,
	EOF = EOF,
	tokens = TK,
	chars = chars
}