-- Lexer tokens
local tokens = {
	"eof", "nil", "false", "true";
	"local", "return", "break", "goto";
	"not", "and", "or";
	"if", "then", "else", "elseif";
	"do", "end", "function", "for", "in", "repeat", "until", "while";
	"minus", "plus", "assign", "less", "greater", "div", "mul", "modulo", "pow", "lparen", "rparen", "len", "comma", "terminator", "lcurbrace", "rcurbrace", "lbrace", "rbrace";
	"eq", "ge", "le", "ne";
	"dot", "method", "concat", "dots", "label", "number", "name", "string",
}

local reserved = {}

-- 2 = nil, 23 = while
for k = 2, 23 do
	reserved[tokens[k]] = k
end

-- Convert tokens to numbers
for k = 1, #tokens do
	tokens[tokens[k]] = k
end

-- Token name table, we use metatable to fallback to their literal name
local tokennames = setmetatable({
	[tokens.eof] = "<eof>";
	[tokens.minus] = "-",
	[tokens.plus] = "+",
	[tokens.assign] = "=",
	[tokens.less] = "<",
	[tokens.greater] = ">",
	[tokens.div] = "/",
	[tokens.mul] = "*",
	[tokens.modulo] = "%",
	[tokens.pow] = "^",
	[tokens.lparen] = "(",
	[tokens.rparen] = ")",
	[tokens.len] = "#",
	[tokens.comma] = ",",
	[tokens.terminator] = ";",
	[tokens.lcurbrace] = "{",
	[tokens.rcurbrace] = "}",
	[tokens.lbrace] = "[",
	[tokens.rbrace] = "]";
	[tokens.eq] = "==",
	[tokens.ge] = ">=",
	[tokens.le] = "<=",
	[tokens.ne] = "~=";
	[tokens.concat] = ".",
	[tokens.concat] = ":",
	[tokens.concat] = "..",
	[tokens.dots] = "...",
	[tokens.label] = "::",
	[tokens.number] = "<number>",
	[tokens.name] = "<name>",
	[tokens.string] = "<string>";
}, {
	__index = tokens
})

return {
	tokens = tokens,
	tokennames = tokennames,
	reserved = reserved
}