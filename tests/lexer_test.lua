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

-- Testing lexing separately
do
	local function GetToken(script)
		local lex = Lexer.Setup(script)
		local _, err = pcall(Lexer.Next, lex)

		return err or lex.tok
	end

	local function TestToken(script, token)
		local a = GetToken(script)
		assert_cmp(tokennames[a] or a, tokennames[token], "Token mismatch.")
	end

	TestToken("", tokens.eof)
	TestToken("           ", tokens.eof)
	TestToken("      \t\t\t\t\t\t\n\n\n     ", tokens.eof)

	do
		local lex = Lexer.Setup("      \t\t\t\t\t\t\n\n\n     ")
		Lexer.Next(lex)
		assert_cmp(lex.linenumber, 4, "lex.linenumber is not counted properly")
		assert_cmp(lex.columnnumber, 5, "lex.columnnumber is not counted properly")
	end

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