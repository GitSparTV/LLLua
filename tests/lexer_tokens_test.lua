require("test_tools")
local Lexer = require("lexer")
local TK = Lexer.tokens
local tokens, tokennames, reservedtokens = TK.tokens, TK.tokennames, TK.reserved

local ShouldHave = {
	"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "concat", "dots", "eq", "ge", "le", "ne", "label", "number", "name", "string", "eof";
	"plus", "minus", "mul", "div", "mod", "pow", "len", "less", "greater", "assign", "lparen", "rparen", "lcurbrace", "rcurbrace", "lbrace", "rbrace", "semicolon", "colon", "comma", "dot", "tilde"
}

local Map = {}

for k, v in ipairs(ShouldHave) do
	Map[v] = k
end

do
	local Names = {
		"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "..", "...", "==", ">=", "<=", "~=", "::", "<number>", "<name>", "<string>", "<eof>";
		"+", "-", "*", "/", "%", "^", "#", "<", ">", "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "~"
	}

	for k, v in pairs(tokens) do
		if type(k) ~= "number" then
			assert(Map[k] ~= nil, "lexer.tokens.tokens has unknown token [", tostring(k), "] = ", tostring(v))
			assert_cmp(v, Map[k], "Token ", k, " has different id")
			assert_cmp(tokennames[v], Names[v], "lexer.tokens.tokennames returns different name")
		end
	end
end

do
	local Reserved = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}

	for k, v in pairs(reservedtokens) do
		assert(Reserved[v] ~= nil, "lexer.tokens.reserved has unknown reserved token [", tostring(k), "] = ", tostring(v))
		assert_cmp(k, Reserved[v], "Not a reserved token")
	end
end