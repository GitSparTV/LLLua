-- Lexer tokens
local tokens = {
	"and", "break", "do", "else", "elseif", "end", "false";
	"for", "function", "goto", "if", "in", "local", "nil", "not", "or";
	"repeat", "return", "then", "true", "until", "while";
	"concat", "dots", "eq", "ge", "le", "ne";
	"label", "number", "name", "string";
	"eof";
	"plus", "minus", "mul", "div", "mod", "pow", "len";
	"less", "greater", "assign", "lparen", "rparen", "lcurbrace", "rcurbrace", "lbrace", "rbrace";
	"semicolon", "colon", "comma", "dot", "tilde";
}

local reserved = {}

-- 1 = and, 22 = while
for k = 1, 22 do
	reserved[tokens[k]] = k
end

-- Convert tokens to numbers
for k = 1, #tokens do
	tokens[tokens[k]] = k
end

-- Token names table, we use metatable to fallback to their literal name
local tokennames = setmetatable({
	[tokens.concat] = "..",
	[tokens.dots] = "...",
	[tokens.eq] = "==",
	[tokens.ge] = ">=",
	[tokens.le] = "<=",
	[tokens.ne] = "~=";
	[tokens.label] = "::",
	[tokens.number] = "<number>",
	[tokens.name] = "<name>",
	[tokens.string] = "<string>";
	[tokens.eof] = "<eof>";
	[tokens.plus] = "+",
	[tokens.minus] = "-",
	[tokens.mul] = "*",
	[tokens.div] = "/",
	[tokens.mod] = "%",
	[tokens.pow] = "^",
	[tokens.greater] = ">";
	[tokens.less] = "<",
	[tokens.lbrace] = "[",
	[tokens.rbrace] = "]",
	[tokens.lcurbrace] = "{",
	[tokens.rcurbrace] = "}",
	[tokens.lparen] = "(",
	[tokens.rparen] = ")";
	[tokens.assign] = "=",
	[tokens.dot] = ".",
	[tokens.comma] = ",",
	[tokens.colon] = ":",
	[tokens.semicolon] = ";",
	[tokens.len] = "#";
	[tokens.tilde] = "~";
}, {
	__index = tokens
})

return {
	tokens = tokens,
	tokennames = tokennames,
	reserved = reserved
}