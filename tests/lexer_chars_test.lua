require("test_tools")
local Lexer = require("lexer")
local chars = Lexer.chars

-- Masks test
do
	assert_cmp(chars.cntrl, 0x01, "")
	assert_cmp(chars.space, 0x02, "")
	assert_cmp(chars.punct, 0x04, "")
	assert_cmp(chars.digit, 0x08, "")
	assert_cmp(chars.xdigit, 0x10, "")
	assert_cmp(chars.upper, 0x20, "")
	assert_cmp(chars.lower, 0x40, "")
	assert_cmp(chars.ident, 0x80, "")
	assert_cmp(chars.alpha, bit.bor(0x40, 0x20), "")
	assert_cmp(chars.alnum, bit.bor(bit.bor(0x40, 0x20), 0x08), "")
	assert_cmp(chars.graph, bit.bor(bit.bor(bit.bor(0x40, 0x20), 0x08), 0x04), "")
end

-- Char bits test
do
	local ffi = require('ffi')

	local luajit_char_bits = ffi.new("const uint8_t[257]", {
		0;
		1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 3, 3, 3, 1, 1;
		1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1;
		2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4;
		152, 152, 152, 152, 152, 152, 152, 152, 152, 152, 4, 4, 4, 4, 4, 4;
		4, 176, 176, 176, 176, 176, 176, 160, 160, 160, 160, 160, 160, 160, 160, 160;
		160, 160, 160, 160, 160, 160, 160, 160, 160, 160, 160, 4, 4, 4, 4, 132;
		4, 208, 208, 208, 208, 208, 208, 192, 192, 192, 192, 192, 192, 192, 192, 192;
		192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 4, 4, 4, 4, 1;
		128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128;
		128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128;
		128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128;
		128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128;
		128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128;
		128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128;
		128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128;
		128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128;
	})

	for i = 0, ffi.sizeof(luajit_char_bits) - 1 do
		assert_cmp(luajit_char_bits[i], chars.char_bits[i], "Character ", i, "(", i ~= 0 and string.char(i - 1) or "", ") has different mask")
	end

	for k, v in pairs(chars.char_bits) do
		assert(type(k) == "number" and (k >= 0 and k <= 256), "chars.char_bits has an extra key [", tostring(k), "] = ", tostring(v), ".")
	end

	-- chars.isa test
	do
		for i = 0, ffi.sizeof(luajit_char_bits) - 2 do
			assert(chars.isa(i, luajit_char_bits[i + 1]), "chars.isa doesn't return proper result for i = ", i, ".")
		end
	end
end

-- Char mask maps test
do
	local iseol = {
		[string.byte("\r")] = true,
		[string.byte("\n")] = true
	}

	for i = -1, #chars.char_bits - 1 do
		assert_cmp(chars.iscntrl[i] or false, chars.isa(i, 0x01), "chars.iscntrl doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.isspace[i] or false, chars.isa(i, 0x02), "chars.isspace doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.ispunct[i] or false, chars.isa(i, 0x04), "chars.ispunct doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.isdigit[i] or false, chars.isa(i, 0x08), "chars.isdigit doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.isxdigit[i] or false, chars.isa(i, 0x10), "chars.isxdigit doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.isupper[i] or false, chars.isa(i, 0x20), "chars.isupper doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.islower[i] or false, chars.isa(i, 0x40), "chars.islower doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.isident[i] or false, chars.isa(i, 0x80), "chars.isident doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.isalpha[i] or false, chars.isa(i, bit.bor(0x40, 0x20)), "chars.isalpha doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.isalnum[i] or false, chars.isa(i, bit.bor(bit.bor(0x40, 0x20), 0x08)), "chars.isalnum doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.isgraph[i] or false, chars.isa(i, bit.bor(bit.bor(bit.bor(0x40, 0x20), 0x08), 0x04)), "chars.isgraph doesn't return proper result for for i = ", i, ".")
		assert_cmp(chars.iseol[i] or false, iseol[i] or false, "chars.iseol doesn't return proper result for for i = ", i, ".")
		if i ~= -1 then
			assert_cmp(string.char(chars.toupper(i)), string.char(i):upper(), "chars.toupper doesn't return proper result for i = ", i, ".")
			assert_cmp(string.char(chars.tolower(i)), string.char(i):lower(), "chars.tolower doesn't return proper result for i = ", i, ".")
		end
	end
end