require("assert_advanced")
package.path = package.path .. "..\\src\\?\\init.lua;..\\src\\?.lua;"

local LJTokensEnum = {"TK_and", "TK_break", "TK_do", "TK_else", "TK_elseif", "TK_end", "TK_false", "TK_for", "TK_function", "TK_goto", "TK_if", "TK_in", "TK_local", "TK_nil", "TK_not", "TK_or", "TK_repeat", "TK_return", "TK_then", "TK_true", "TK_until", "TK_while", "TK_concat", "TK_dots", "TK_eq", "TK_ge", "TK_le", "TK_ne", "TK_label", "TK_number", "TK_name", "TK_string", "TK_eof"}

local counter = 257

for k, v in ipairs(LJTokensEnum) do
	LJTokensEnum[counter] = v
	LJTokensEnum[k] = nil
	counter = counter + 1
end

local characters = {"+", "-", "*", "/", "%", "^", "#", "<", ">", "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", "."}

for _, v in ipairs(characters) do
	LJTokensEnum[string.byte(v)] = v
end

local Lexer = require("lexer")
local tokens = Lexer.tokens.tokens
local tokennames = Lexer.tokens.tokennames

local TokenMap = {
	TK_and = tokens["and"],
	TK_break = tokens["break"],
	TK_do = tokens["do"],
	TK_else = tokens["else"],
	TK_elseif = tokens["elseif"],
	TK_end = tokens["end"],
	TK_false = tokens["false"],
	TK_for = tokens["for"],
	TK_function = tokens["function"],
	TK_goto = tokens["goto"],
	TK_if = tokens["if"],
	TK_in = tokens["in"],
	TK_local = tokens["local"],
	TK_nil = tokens["nil"],
	TK_not = tokens["not"],
	TK_or = tokens["or"],
	TK_repeat = tokens["repeat"],
	TK_return = tokens["return"],
	TK_then = tokens["then"],
	TK_true = tokens["true"],
	TK_until = tokens["until"],
	TK_while = tokens["while"],
	TK_concat = tokens["concat"],
	TK_dots = tokens["dots"],
	TK_eq = tokens["eq"],
	TK_ge = tokens["ge"],
	TK_le = tokens["le"],
	TK_ne = tokens["ne"],
	TK_label = tokens["label"],
	TK_number = tokens["number"],
	TK_name = tokens["name"],
	TK_string = tokens["string"],
	TK_eof = tokens["eof"],
	["+"] = tokens["plus"],
	["-"] = tokens["minus"],
	["*"] = tokens["mul"],
	["/"] = tokens["div"],
	["%"] = tokens["mod"],
	["^"] = tokens["pow"],
	[">"] = tokens["greater"],
	["<"] = tokens["less"],
	["["] = tokens["lbrace"],
	["]"] = tokens["rbrace"],
	["{"] = tokens["lcurbrace"],
	["}"] = tokens["rcurbrace"],
	["("] = tokens["lparen"],
	[")"] = tokens["rparen"],
	["="] = tokens["assign"],
	["."] = tokens["dot"],
	[","] = tokens["comma"],
	[":"] = tokens["colon"],
	[";"] = tokens["semicolon"],
	["#"] = tokens["len"],
	["~"] = tokens["tilde"],
}

-- Testing internals
do
	-- Setup and Lexer.Next()
	do
		assert_cmp(Lexer.EOF, -1, "Lexer.EOF is not -1")

		local lex = Lexer.Setup("")

		assert_cmp(lex.buf, "", "Input buffer is not saved to lex.buf")
		assert_cmp(lex.size, 0, "lex.size of the input buffer is wrong")
		assert_cmp(lex.offset, 1, "Incorrect initial lex.offset")
		assert_cmp(lex.c, Lexer.EOF, "lex.c is not EOF")
		assert_cmp(lex.linenumber, 1, "lex.linenumber is not initialized properly")
		assert_cmp(lex.columnnumber, 0, "lex.columnnumber is not initialized properly")
		assert_cmp(lex.lastline, 1, "lex.lastline is not initialized properly")
		assert_cmp(#lex.strbuf, 64, "lex.strbuf is not preallocated")
		assert_cmp(lex.strbufsize, 0, "lex.strbufsize is not initialized properly")
		assert_cmp(lex.strbufresult, "", "lex.strbufresult is not initialized properly")
		assert_cmp(lex.tok, -1, "lex.tok is not initialized properly")
		assert_cmp(lex.lookahead, tokens.eof, "lex.lookahead is not EOF")

		Lexer.Next(lex)

		assert_cmp(lex.buf, "", "lex.buf changed at runtime")
		assert_cmp(lex.size, 0, "lex.size changed at runtime")
		assert_cmp(lex.offset, 1, "lex.offset moved even when there is no more characters to read")
		assert_cmp(lex.c, Lexer.EOF, "lex.c is not EOF")
		assert_cmp(lex.linenumber, 1, "lex.linenumber should not be changed")
		assert_cmp(lex.columnnumber, 0, "lex.columnnumber should not be changed")
		assert_cmp(lex.lastline, 1, "lex.lastline should not be changed")
		assert_cmp(lex.strbufsize, 0, "lex.strbufsize should not be changed")
		assert_cmp(lex.strbufresult, "", "lex.strbufresult should not be changed")
		assert_cmp(lex.tok, tokens.eof, "lex.tok is not EOF")
		assert_cmp(lex.lookahead, tokens.eof, "lex.lookahead is not EOF")
	end

	-- lex.linenumber, lex.columnnumber, lex.lastline
	do
		local lex = Lexer.Setup("      \t\t\t\t\t\t\n\n\n     ")

		Lexer.Next(lex)

		assert_cmp(lex.linenumber, 4, "lex.linenumber is not counted properly")
		assert_cmp(lex.columnnumber, 5, "lex.columnnumber is not counted properly")
		assert_cmp(lex.lastline, 1, "lex.lastline is not counted properly")

		Lexer.Next(lex)

		assert_cmp(lex.lastline, 4, "lex.lastline is not counted properly")
	end

	do
		local lex = Lexer.Setup(string.rep(" \t\v\f ", 10))

		Lexer.Next(lex)

		assert_cmp(lex.columnnumber, 50, "lex.columnnumber is not counted properly")
	end

	-- lex:Next()
	do
		local str = "abcdefg"
		local lex = Lexer.Setup(str)

		assert_cmp(lex.c, string.byte(str, 1), "lex.c is not initialized with first character")

		for k = 2, #str do
			assert_cmp(lex(), string.byte(str, k), "Wrong read in lex.с in character #", k)
		end

		assert_cmp(lex(), Lexer.EOF, "lex.c is not set to EOF when the all characters are read")
		assert_cmp(lex(), Lexer.EOF, "lex.c should be always EOF when the all characters are read")
	end

	-- lex:Save(), lex:SaveN(), lex:SaveNext(), lex:ConcatStrBuffer(), lex:ResetStrBuffer()
	do
		local str = "1234567890"
		local lex = Lexer.Setup(str)

		do
			lex:Save("q")
			lex:Save("w")
			lex:Save("e")
			lex:Save("r")
			lex:Save("t")
			lex:Save("y")

			assert_cmp(lex:ConcatStrBuffer(), "qwerty", "lex:ConcatStrBuffer() returns incorrect string")

			lex:ResetStrBuffer()

			assert_cmp(lex.strbufsize, 0, "lex.strbufsize is not reset")
		end

		do
			lex:SaveN(1)
			lex:SaveN(2)
			lex:SaveN(3)
			lex:SaveN(4)
			lex:SaveN(5)
			lex:SaveN(6)

			assert_cmp(lex:ConcatStrBuffer(), "\1\2\3\4\5\6", "lex:ConcatStrBuffer() returns incorrect string")

			lex:ResetStrBuffer()

			assert_cmp(lex.strbufsize, 0, "lex.strbufsize is not reset")
		end

		do
			local counter = 0

			while lex:SaveNext() ~= Lexer.EOF do
				counter = counter + 1

				assert_cmp(lex.strbufsize, counter, "lex.strbufsize is not counted properly")
				assert_cmp(lex:ConcatStrBuffer(), str:sub(1, counter), "lex:ConcatStrBuffer() returns incorrect string")
			end

			lex:ResetStrBuffer()

			assert_cmp(lex.strbufsize, 0, "lex.strbufsize is not reset")
		end
	end

	-- lex:SkipEq()
	do
		do
			local lex = Lexer.Setup("[")

			assert_cmp(lex:SkipEq(), -1, "lex:SkipEq() is not counting properly")
		end

		do
			local lex = Lexer.Setup("[[")

			assert_cmp(lex:SkipEq(), 0, "lex:SkipEq() is not counting properly")
		end

		do
			local lex = Lexer.Setup("[===")

			assert_cmp(lex:SkipEq(), -4, "lex:SkipEq() is not counting properly")
		end

		do
			local lex = Lexer.Setup("[======[")

			assert_cmp(lex:SkipEq(), 6, "lex:SkipEq() is not counting properly")
		end
	end

	-- lex:LongComment()
	do
		local lex = Lexer.Setup("[=[\n12345]]678]===]90\n]=]")

		lex:LongComment(1)

		assert_cmp(lex.strbuf[0], false, "lex:LongComment() should not save into lex.strbuf")
		assert_cmp(lex.linenumber, 3, "lex:LongComment() doesn't increment lex.linenumber")
		assert_cmp(lex.c, Lexer.EOF, "lex.c is not EOF")
	end

	-- lex:LongString()
	do
		local lex = Lexer.Setup("[===[\n12345]]6]===78]===]90\n]===]")
		lex()
		lex()
		lex()
		lex()
		lex:LongString(3)

		assert_cmp(lex.linenumber, 2, "lex:LongComment() doesn't increment lex.linenumber")
		assert_cmp(lex.c, string.byte("9"), "lex.c didn't end on next character after ]")
		assert_cmp(lex:ConcatStrBuffer(), [===[
12345]]6]===78]===], "Incorrect saving in lex:LongString()")
	end

	-- lex:Number()
	do
		do
			local lex = Lexer.Setup("1234567890")
			lex:Number()
			assert_cmp(lex:ConcatStrBuffer(), "1234567890", "lex:Number() doesn't read numbers properly")
		end

		do
			local lex = Lexer.Setup("123e-1")
			lex:Number()
			assert_cmp(lex:ConcatStrBuffer(), "123e-1", "lex:Number() doesn't read numbers properly")
		end

		do
			local lex = Lexer.Setup("123.1")
			lex:Number()
			assert_cmp(lex:ConcatStrBuffer(), "123.1", "lex:Number() doesn't read numbers properly")
		end

		do
			local lex = Lexer.Setup("00001")
			lex:Number()
			assert_cmp(lex:ConcatStrBuffer(), "00001", "lex:Number() doesn't read numbers properly")
		end

		do
			local lex = Lexer.Setup("0xAbCdEfp-1")
			lex:Number()
			assert_cmp(lex:ConcatStrBuffer(), "0xAbCdEfp-1", "lex:Number() doesn't read numbers properly")
		end

		do
			local lex = Lexer.Setup("0XABCDE-3")
			lex:Number()
			assert_cmp(lex:ConcatStrBuffer(), "0XABCDE", "lex:Number() doesn't read numbers properly")
		end
	end

	do
		local lex = Lexer.Setup("\n\r\n\n\r\r\r")

		for k = 2, 5 do
			lex:Newline()
			assert_cmp(lex.linenumber, k, "Incorrect lex.linenumber incrementing")
		end
	end
end

-- Testing lexing separately
do
	local function GetToken(script)
		local lex = Lexer.Setup(script)
		local _, err = pcall(Lexer.Next, lex)

		return err or lex.tok
	end

	local function TestToken(script, token)
		local a = GetToken(script)

		assert_stack(1)
		assert_cmp(tokennames[a] or a, tokennames[token], "Token mismatch.")
	end

	TestToken("", tokens.eof)
	TestToken("           ", tokens.eof)
	TestToken("      \t\t\t\t\t\t\n\n\n     ", tokens.eof)
	TestToken("1234.67890", tokens.number)
	TestToken("1", tokens.number)
	TestToken("0xabcdFE", tokens.number)
	TestToken("and", tokens["and"])
	TestToken("         and                ", tokens["and"])
	TestToken("    break", tokens["break"])
	TestToken("\n\n\nuntil", tokens["until"])
	TestToken("\n\n\nwhile", tokens["while"])
	TestToken("variable", tokens.name)
	TestToken("v", tokens.name)
	TestToken("vscdkjhdfsakjhadfskjhfadskjlhfadskjh", tokens.name)
	TestToken("-", tokens.minus)
	TestToken("--", tokens.eof)
	TestToken("--hihsidhish", tokens.eof)
	TestToken("-- 209eund20-9n", tokens.eof)
	TestToken("--[[]]", tokens.eof)
	TestToken("--[=[]=]", tokens.eof)
	TestToken("--[[sdkjahdksj]]", tokens.eof)
	TestToken("--[============[sdkjahdksj]============]", tokens.eof)
	TestToken("--[============[sdk[====[jah]]dk]=====]sj]============]", tokens.eof)
	TestToken("[=[]=]", tokens.string)
	TestToken("[[sdkjahdksj]]", tokens.string)
	TestToken("[============[sdkjahdksj]============]", tokens.string)
	TestToken("[============[sdk[====[jah]]dk]=====]sj]============]", tokens.string)
	TestToken("[", tokens.lbrace)
	TestToken("=", tokens.assign)
	TestToken("==", tokens.eq)
	TestToken("=a", tokens.assign)
	TestToken("<dowqij", tokens.less)
	TestToken("< =", tokens.less)
	TestToken("<=dsds", tokens.le)
	TestToken(">", tokens.greater)
	TestToken(">=", tokens.ge)
	TestToken("~", tokens.tilde)
	TestToken("~=", tokens.ne)
	TestToken(":", tokens.colon)
	TestToken("::", tokens.label)
	TestToken("\"\"", tokens.string)
	TestToken("\"test\"", tokens.string)
	TestToken("\'test\'", tokens.string)
	TestToken("\"te        st\"", tokens.string)
	TestToken("\"te\\\"st\"", tokens.string)
	TestToken("\"te\\nst\"", tokens.string)
	TestToken("\"te\\a\\b\\fst\"", tokens.string)
	TestToken("\"te\\xFfst\"", tokens.string)
	TestToken("\"te\\u{1234}st\"", tokens.string)
	TestToken("\"te\\1st\"", tokens.string)
	TestToken("\"te\\001st\"", tokens.string)
	TestToken("\"       test\\z\nfljsdljkhdskjlsh \"", tokens.string)
	TestToken(".", tokens.dot)
	TestToken("..", tokens.concat)
	TestToken("...", tokens.dots)
	TestToken(".2323", tokens.number)
	TestToken(".33434", tokens.number)
	TestToken("+", tokens.plus)
	TestToken("    +dsad", tokens.plus)
	TestToken("*", tokens.mul)
	TestToken("/", tokens.div)
	TestToken("%", tokens.mod)
	TestToken("^", tokens.pow)
	TestToken("]", tokens.rbrace)
	TestToken("{", tokens.lcurbrace)
	TestToken("}", tokens.rcurbrace)
	TestToken("(", tokens.lparen)
	TestToken(")", tokens.rparen)
	TestToken("=", tokens.assign)
	TestToken(",", tokens.comma)
	TestToken(";", tokens.semicolon)
	TestToken("#", tokens.len)
end

-- Testing lexing errors
do
	local function GetError(script)
		local lex = Lexer.Setup(script)
		local _, err = pcall(Lexer.Next, lex)

		return err
	end

	local function TestMethod(script, error, method, ...)
		local lex = Lexer.Setup(script)
		local _, err = pcall(lex[method], lex, ...)

		assert_stack(1)
		assert(tostring(err):find(error, nil, true), "Error mismatch. (Expected: ", error, ", got ", tostring(err), ")")
	end

	local function TestError(script, error, hint)
		local err = tostring(GetError(script))

		assert_stack(1)
		assert(err:find(error, nil, true), "Error mismatch in ", hint, ". (Expected: ", error, ", got ", err, "). Test ")
	end

	TestMethod("notanewline", "bad usage", "Newline")

	do
		local lex = Lexer.Setup("\n")
		local MAX_LENGTH = 0x7fffff00
		lex.linenumber = MAX_LENGTH - 1
		local _, err = pcall(lex.Newline, lex)

		assert(tostring(err):find("LJ_ERR_XLINES", nil, true), "Error mismatch when lex.linenumber exceeds limit. (Expected: LJ_ERR_XLINES, got ", tostring(err), ")")
	end

	TestMethod("notanumber", "bad usage", "Number")
	TestMethod("notabrace", "bad usage", "SkipEq")
	TestMethod("notabrace", "bad usage", "SkipEqComment")
	TestError("[[", "LJ_ERR_XLSTR", "lex:LongString()")
	TestError("--[===[", "LJ_ERR_XLCOM", "lex:LongComment()")
	TestError("\"", "LJ_ERR_XSTR", "lex:String() on EOF")
	TestError("\"\n\"", "LJ_ERR_XSTR", "lex:String() on newline")
	TestError("\"\n\"", "LJ_ERR_XSTR", "lex:String() on newline")
	TestError("\"\\xQ\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\x with first invalid character")
	TestError("\"\\x1G\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\x with second invalid character")
	TestError("\"\\xAG\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\x with second invalid character")
	TestError("\"\\xAG\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\x with second invalid character")
	TestError("\"\\u\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when first character is not `{`")
	TestError("\"\\u{\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when sequence is not enclosed with `}`")
	TestError("\"\\u{}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when sequence is empty")
	TestError("\"\\u{Q}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u with invalid character")
	TestError("\"\\u{110000}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when the number is out of Unicode range")
	TestError("\"\\u{110001}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when the number is out of Unicode range")
	TestError("\"\\u{FFFFFF}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when the number is out of Unicode range")
	TestError("\"\\u{d800}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when the number is a surrogate")
	TestError("\"\\u{d801}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when the number is a surrogate")
	TestError("\"\\u{DFfF}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when the number is a surrogate")
	TestError("\"\\u{dffe}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when the number is a surrogate")
	TestError("\"\\u{DBFF}\"", "LJ_ERR_XESC", "lex:String() on escape sequence \\u when the number is a surrogate")
	TestError("\"\\lol\"", "LJ_ERR_XESC", "lex:String() on invalid escape sequence")
	TestError("\"\\why\"", "LJ_ERR_XESC", "lex:String() on invalid escape sequence")
	TestError("\"\\256\"", "LJ_ERR_XESC", "lex:String() on numeric escape sequence when the number is higher than 255")
	TestError("\"\\999\"", "LJ_ERR_XESC", "lex:String() on numeric escape sequence when the number is higher than 255")
	TestError("[==", "LJ_ERR_XLDELIM", "long string literal")

	do
		TestMethod("", "lex.c is out of range (-1)", "SaveNext")
		TestMethod("", "char is out of range (-1)", "SaveN", -1)
		TestMethod("", "char is out of range (1000)", "SaveN", 1000)
	end

	do
		local lex = Lexer.Setup("a b c")

		lex:Lookahead()
		local _, err = pcall(lex.Lookahead, lex)

		assert(tostring(err):find("double lookahead", nil, true), "Error mismatch when lex:Lookahead() is called twice. (Expected: double lookahead, got ", tostring(err), ")")
	end

	do
		local lex = Lexer.Setup("-")

		local original = tokens.minus
		tokens.minus = nil
		local _, err = pcall(Lexer.Next, lex)
		tokens.minus = original

		assert(tostring(err):find("token is nil", nil, true), "Error mismatch when lex.tok is not defined in Lexer.Next (Expected: , got ", tostring(err), ")")
	end

	do
		local lex = Lexer.Setup("-")

		local original = tokens.minus
		tokens.minus = nil
		local _, err = pcall(lex.Lookahead, lex)
		tokens.minus = original

		assert(tostring(err):find("token is nil", nil, true), "Error mismatch when lex.tok is not defined in lex:Lookahead() (Expected: , got ", tostring(err), ")")
	end
end

-- Testing lexing consistency with LuaJIT
do
	local function ParseLJTokens(file)
		local f = io.popen("lexluajit.exe " .. file, "r")
		local result = {}

		for line in f:lines() do
			result[#result + 1] = tonumber(line)
		end

		return result
	end

	local LJTokens = ParseLJTokens("_luajit_tokens_consistency.lua")
	local LLLuaTokens = {}

	do
		local file = io.open("_luajit_tokens_consistency.lua")
		local lex = Lexer.Setup(file:read("*a"))
		file:close()

		while lex.tok ~= tokens.eof do
			Lexer.Next(lex)
			LLLuaTokens[#LLLuaTokens + 1] = lex.tok
		end
	end

	assert_cmp(#LJTokens, #LLLuaTokens, "Incorrect amount of tokens")

	for k, v in ipairs(LLLuaTokens) do
		assert_cmp(TokenMap[LJTokensEnum[LJTokens[k]]], v, "Token ", k, " mismatch. ", LJTokensEnum[LJTokens[k]], " ", tokennames[v])
	end
end

-- TODO: number reading
-- TODO: string reading
-- TODO: string escapes reading